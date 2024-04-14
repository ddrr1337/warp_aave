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

    bool public isNodeActive;

    mapping(address => bool) public validNodes;

    //////////////////////////TESTING///////////////////
    uint256 aUsdcCheckpointReference;

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
        (
            uint8 command,
            address userAddress,
            uint256 amount,
            uint256 totalAusdcNode
        ) = abi.decode(
                _any2EvmMessage.data,
                (uint8, address, uint256, uint256)
            );

        uint256 aWRPTotalSupply = totalSupply();
        uint256 shares;
        if (aWRPTotalSupply == 0) {
            shares = amount;
        } else {
            shares = (amount * aWRPTotalSupply) / totalAusdcNode;
        }

        aUsdcCheckpointReference = totalAusdcNode + amount;

        _mint(userAddress, shares * 10 ** 12);

        // TESTING //
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            validNodes[abi.decode(any2EvmMessage.sender, (address))],
            "Request from invalid node"
        );

        uint8 command = internalCommandRouter(any2EvmMessage);

        if (command == 0) {
            aWarpTokenMinter(any2EvmMessage);
        } else {
            revert("invalid command from Slave");
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
                Client.EVMExtraArgsV1({gasLimit: 2_000_000})
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
        validNodes[_node] = true;
    }

    // cambiar esto para que los datos vayan codificados en bytes
    function warpAssets(
        uint64 _destinationChainSelector,
        address nodeAddressReceiver,
        uint32 circleChainId,
        bytes32 mintRecipient
    ) public {
        require(validNodes[nodeAddressReceiver], "Forbbiden, node not valid");
        uint8 command = 0;
        bytes memory data = abi.encode(command, circleChainId, mintRecipient);
        _sendMessage(_destinationChainSelector, nodeAddressReceiver, data);
    }

    function withdraw(
        uint64 _destinationChainSelector,
        address nodeAddressReceiver,
        uint256 amount
    ) external {
        require(validNodes[nodeAddressReceiver], "Forbbiden, node not valid");
        require(amount <= balanceOf(msg.sender), "Not enought balance");

        uint8 command = 1;

        bytes memory data = abi.encode(
            command,
            msg.sender,
            amount,
            totalSupply(),
            aUsdcCheckpointReference
        );
        _burn(msg.sender, amount);

        _sendMessage(_destinationChainSelector, nodeAddressReceiver, data);
    }
}
