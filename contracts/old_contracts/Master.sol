// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Master is ERC20, CCIPReceiver {
    event Withdraw(address indexed from, uint256 amount, uint256 timestamp);
    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender // The address of the sender from the source chain.
    );
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    uint64 public immutable MASTER_CHAIN;
    address public activeNode;
    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    struct ValidNodes {
        bool isValidNode;
        bool isActiveNode;
        uint64 chainCCIPid;
        uint256 lastDataFromAave;
        uint256 totalUsdcSupply;
        uint256 totalUsdcBorrow;
        uint256 supplyRate;
        uint256 nodeLinkBalance;
        uint256 lastLinkFees;
    }

    mapping(address => ValidNodes) public validNodes;

    uint256 public constant LINK_BUFFER = 1 * 10 ** 18;

    //////////////////////////TESTING///////////////////
    uint256 public lastTimeWarped;

    ///////////////////////////////CONSTRUCTOR//////////////////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    constructor(
        address _router,
        address _link,
        uint64 _MASTER_CHAIN
    ) ERC20("WarpYield", "aWRP") CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        MASTER_CHAIN = _MASTER_CHAIN;
    }

    function internalCommandRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) public returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));

        return command;
    }

    function aWarpTokenMinter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) public {
        (, address userAddress, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint256)
        );

        _mint(userAddress, shares);

        // TESTING //
    }

    function nodeAaveFeed(Client.Any2EVMMessage memory _any2EvmMessage) public {
        require(
            validNodes[abi.decode(_any2EvmMessage.sender, (address))]
                .isValidNode,
            "Node is not valid"
        );

        (
            ,
            uint256 totalUsdcSupply,
            uint256 totalUsdcBorrow,
            uint256 supplyRate,
            uint256 nodeLinkBalance,
            uint256 lastLinkFees
        ) = abi.decode(
                _any2EvmMessage.data,
                (uint8, uint256, uint256, uint256, uint256, uint256)
            );

        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .lastDataFromAave = block.timestamp;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcSupply = totalUsdcSupply;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcBorrow = totalUsdcBorrow;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .supplyRate = supplyRate;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .nodeLinkBalance = nodeLinkBalance;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .lastLinkFees = lastLinkFees;
    }

    function _resumeWithdrawsNodeActive(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .isActiveNode = true;
        activeNode = abi.decode(_any2EvmMessage.sender, (address));
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            validNodes[abi.decode(any2EvmMessage.sender, (address))]
                .isValidNode,
            "Request from invalid Node"
        );

        uint8 command = internalCommandRouter(any2EvmMessage);

        if (command == 0) {
            aWarpTokenMinter(any2EvmMessage);
        } else if (command == 1) {
            nodeAaveFeed(any2EvmMessage);
        } else if (command == 2) {
            _resumeWithdrawsNodeActive(any2EvmMessage);
        } else {
            revert("invalid command from Node");
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)) // abi-decoding of the sender address,
        );
    }

    function _sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory _data
    ) internal returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: _data, // ABI-encoded data
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(s_linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );
        require(
            s_linkToken.transferFrom(msg.sender, address(this), fees),
            "Not Link transfered for paying CCIP fees"
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function addValidNode(
        address nodeAddress,
        uint64 chainCCIPid,
        bool isActiveNode
    ) public {
        validNodes[nodeAddress].isValidNode = true;
        validNodes[nodeAddress].chainCCIPid = chainCCIPid;
        validNodes[nodeAddress].isActiveNode = isActiveNode;
        if (isActiveNode) {
            activeNode = nodeAddress;
        }
    }

    function warpAssets(
        uint32 newNodeChainIdCCTPid,
        uint64 newNodeChainIdCCIPid,
        bytes32 newNodeReceiver
    ) external {
        require(
            validNodes[activeNode].isValidNode,
            "Forbbiden, node not valid"
        );
        require(
            validNodes[activeNode].isActiveNode,
            "Forbbiden, node not active"
        );

        bytes memory data = abi.encode(
            uint8(0),
            newNodeChainIdCCTPid,
            newNodeChainIdCCIPid,
            newNodeReceiver
        );
        /*         lastTimeWarped = block.timestamp;
        activeNode = address(0); */
        validNodes[activeNode].isActiveNode = false;

        _sendMessage(validNodes[activeNode].chainCCIPid, activeNode, data);
    }

    function withdraw(uint256 shares) external {
        require(validNodes[activeNode].isActiveNode, "Node is not Active");

        require(shares <= balanceOf(msg.sender), "Not enought balance");

        bytes memory data = abi.encode(uint8(1), msg.sender, shares);

        _burn(msg.sender, shares);

        _sendMessage(validNodes[activeNode].chainCCIPid, activeNode, data);
        emit Withdraw(msg.sender, shares, block.timestamp);
    }

    function getLinkFees(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory _data
    ) public view returns (uint256) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: _data, // ABI-encoded data
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 1_000_000})
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(s_linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );
        return fees;
    }

    function checkApprovedWarp(
        address _activeNode,
        address destinationNode
    ) public view returns (bool) {
        uint256 now = block.timestamp;

        return
            validNodes[_activeNode].isActiveNode == true &&
            validNodes[_activeNode].lastDataFromAave > 0 &&
            validNodes[destinationNode].lastDataFromAave > 0 &&
            validNodes[_activeNode].lastDataFromAave + 3600 > now &&
            validNodes[destinationNode].lastDataFromAave + 3600 > now &&
            validNodes[destinationNode].isValidNode == true &&
            validNodes[destinationNode].isActiveNode == false &&
            validNodes[_activeNode].supplyRate > 0 &&
            validNodes[_activeNode].supplyRate <
            validNodes[destinationNode].supplyRate;
    }

    function testerCheckTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
}
