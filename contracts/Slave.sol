// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITokenMessenger.sol";
import "../interfaces/IPool.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/// @title - A simple contract for receiving string data across chains.
contract Slave is CCIPReceiver {
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
        address receiver, // The address of the receiver on the destination chain.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    uint64 public constant MASTER_CHAIN = 16015286601757825753;
    address public constant MASTER_CONTRACT =
        0x5b3759E7ab559b95Ddf686a650fb586466c4d094;

    address immutable POOL_ADDRESS_PROVIDER; // arbitrum sepolia hardcoded

    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    address public tokenUSDC;
    address public circleTokenMessengerAddress;

    bool public isNodeActive;

    struct Message {
        string message;
        address sender;
    }

    struct WarpIdToDestinationChain {
        uint32 circleChainId;
        bytes32 destinationAddress;
    }

    mapping(bytes32 => WarpIdToDestinationChain)
        public warpIdToDestinationChain;
    bytes32[] public warpIds;

    ////////////////////////// CONSTRUCTOR ///////////////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract (CCIP chainlink router).
    /// @param _link The address of the LINK token contract.
    /// @param _tokenUSDC The address of the Circle USDC token contract.
    /// @param _circleTokenMessengerAddress The address of the Circle token messenger contract.
    /// @param _POOL_ADDRESS_PROVIDER The address of the Pool address provider contract (aave).

    constructor(
        address _router,
        address _link,
        address _tokenUSDC,
        address _circleTokenMessengerAddress,
        address _POOL_ADDRESS_PROVIDER
    ) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);

        tokenUSDC = _tokenUSDC;
        circleTokenMessengerAddress = _circleTokenMessengerAddress;
        POOL_ADDRESS_PROVIDER = _POOL_ADDRESS_PROVIDER;
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            abi.decode(any2EvmMessage.sender, (address)) == MASTER_CONTRACT,
            "MASTER CONTRACT ONLY"
        );

        (uint32 destinationChainCircle, bytes32 destinationAddress) = abi
            .decode(any2EvmMessage.data, (uint32, bytes32));

        warpIdToDestinationChain[
            any2EvmMessage.messageId
        ] = WarpIdToDestinationChain(
            destinationChainCircle,
            destinationAddress
        );

        warpIds.push(any2EvmMessage.messageId);

        //LOS TOKENS NO ESTAN APROBADOS!!!
        //IERC20(tokenUSDC).approve(circleTokenMessengerAddress, balanceUsdc);

        uint256 balanceUsdc = IERC20(tokenUSDC).balanceOf(address(this));
        IERC20(tokenUSDC).approve(circleTokenMessengerAddress, balanceUsdc);

        ITokenMessenger(circleTokenMessengerAddress).depositForBurn(
            balanceUsdc,
            destinationChainCircle,
            destinationAddress,
            tokenUSDC
        );

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)) // abi-decoding of the sender address,
        );
    }

    function _sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        address userAddress,
        uint256 amount
    ) internal returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: abi.encode(userAddress, amount), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
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
            receiver,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function _getPool() internal view returns (address) {
        address pool = IPoolAddressesProvider(POOL_ADDRESS_PROVIDER).getPool();

        return pool;
    }
    // Add referal code as parameter in case in the future activates again

    function deposit(uint256 amount) external {
        require(
            IERC20(tokenUSDC).transferFrom(msg.sender, address(this), amount),
            "Failed to transfer amount"
        );
        address pool = _getPool();

        IERC20(tokenUSDC).approve(pool, amount);
        IPool(pool).deposit(tokenUSDC, amount, address(this), 0);

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, msg.sender, amount);
    }
}
