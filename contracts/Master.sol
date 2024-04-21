// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Master is ERC20, CCIPReceiver {
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

    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    struct ActiveNodes {
        bool isValidNode;
        bool isNodeActive;
        uint256 lastDataFromAave;
        uint256 totalUsdcSupply;
        uint256 totalUsdcBorrow;
        uint256 supplyRate;
    }

    mapping(address => ActiveNodes) public activeNodes;

    //////////////////////////TESTING///////////////////

    struct NonceDataWithdraw {
        address userAddress;
        uint256 amount;
    }

    mapping(uint128 => NonceDataWithdraw) public nonceDataWithdraw;
    mapping(address => uint128[]) public userNoncesWithdraw;

    mapping(uint128 => address) public userNoncesDeposits;

    uint128 public mainNonceWithdraw;
    bool public allowedWithdraws = true;

    ///////////////////////////////CONSTRUCTOR//////////////////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    constructor(
        address _router,
        address _link
    ) ERC20("WarpYield", "aWRP") CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
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
        (, address userAddress, uint128 nonce, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint128, uint256)
        );
        require(
            userNoncesDeposits[nonce] == address(0),
            "Nonce already processed"
        );

        userNoncesDeposits[nonce] = userAddress;

        _mint(userAddress, shares);

        // TESTING //
    }

    function nodeAaveFeed(Client.Any2EVMMessage memory _any2EvmMessage) public {
        (
            ,
            uint256 totalUsdcSupply,
            uint256 totalUsdcBorrow,
            uint256 supplyRate
        ) = abi.decode(
                _any2EvmMessage.data,
                (uint8, uint256, uint256, uint256)
            );

        activeNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .lastDataFromAave = block.timestamp;
        activeNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcSupply = totalUsdcSupply;
        activeNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcBorrow = totalUsdcBorrow;
        activeNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .supplyRate = supplyRate;
    }

    function _resumeWithdrawsNodeActive(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        activeNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .isNodeActive = true;
        allowedWithdraws = true;
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            activeNodes[abi.decode(any2EvmMessage.sender, (address))]
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

    function addValidNode(address _node) public {
        activeNodes[_node].isValidNode = true;
    }

    function warpAssets(
        uint64 nodeChainIdCCIP,
        address nodeAddressReceiver,
        uint32 newNodeChainId,
        uint64 newNodeChainIdCCIP,
        bytes32 newNodeReceiver
    ) public {
        require(
            activeNodes[nodeAddressReceiver].isValidNode,
            "Forbbiden, node not valid"
        );
        allowedWithdraws = false;
        uint8 command = 0;
        bytes memory data = abi.encode(
            command,
            newNodeChainId,
            newNodeChainIdCCIP,
            newNodeReceiver
        );
        _sendMessage(nodeChainIdCCIP, nodeAddressReceiver, data);
    }

    function withdraw(
        uint64 _destinationChainSelector,
        address nodeAddressReceiver,
        uint256 shares
    ) external {
        require(
            activeNodes[nodeAddressReceiver].isValidNode,
            "Forbbiden, node not valid"
        );
        require(
            allowedWithdraws,
            "Assets warping withdraws halted in the process"
        );
        require(shares <= balanceOf(msg.sender), "Not enought balance");

        uint8 command = 1;

        bytes memory data = abi.encode(command, msg.sender, shares);
        nonceDataWithdraw[mainNonceWithdraw].userAddress = msg.sender;
        nonceDataWithdraw[mainNonceWithdraw].amount = shares;

        _burn(msg.sender, shares);

        _sendMessage(_destinationChainSelector, nodeAddressReceiver, data);
    }
}
