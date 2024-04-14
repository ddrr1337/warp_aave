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

contract Slave is CCIPReceiver {
    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector // The chain selector of the source chain.
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

    uint64 public constant MASTER_CHAIN = 16015286601757825753; // harcoded sepolia id_cain CCIP
    address public immutable MASTER_CONTRACT;

    address immutable POOL_ADDRESS_PROVIDER;

    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    address public tokenUSDC;
    address public tokenAUSDC;
    address public circleTokenMessengerAddress;

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

    bool public isNodeActive = true;

    uint256 public aUsdcTokenSupply;

    ////////////////////TESTER ////////////////////////
    uint8 public testerCommand;

    ////////////////////////// CONSTRUCTOR ///////////////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract (CCIP chainlink router).
    /// @param _link The address of the LINK token contract.
    /// @param _tokenUSDC The address of the Circle USDC token contract.
    /// @param _tokenAUSDC The address of the ausdc provided by aave when deposit is done.
    /// @param _circleTokenMessengerAddress The address of the Circle token messenger contract.
    /// @param _POOL_ADDRESS_PROVIDER The address of the Pool address provider contract (aave).

    constructor(
        address _router,
        address _link,
        address _tokenUSDC,
        address _tokenAUSDC,
        address _circleTokenMessengerAddress,
        address _POOL_ADDRESS_PROVIDER,
        address _MASTER_CONTRACT
    ) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);

        tokenUSDC = _tokenUSDC;
        tokenAUSDC = _tokenAUSDC;
        circleTokenMessengerAddress = _circleTokenMessengerAddress;
        POOL_ADDRESS_PROVIDER = _POOL_ADDRESS_PROVIDER;
        MASTER_CONTRACT = _MASTER_CONTRACT;
    }

    function internalMessageRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) public returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));

        testerCommand = command;

        return command;
    }

    function warpAssets(Client.Any2EVMMessage memory _any2EvmMessage) public {
        (
            uint8 command,
            uint32 destinationChainCircle,
            bytes32 destinationAddress
        ) = abi.decode(_any2EvmMessage.data, (uint8, uint32, bytes32));

        // set isNodeActive false

        warpIdToDestinationChain[
            _any2EvmMessage.messageId
        ] = WarpIdToDestinationChain(
            destinationChainCircle,
            destinationAddress
        );

        warpIds.push(_any2EvmMessage.messageId);

        uint256 balanceUsdc = IERC20(tokenUSDC).balanceOf(address(this));
        IERC20(tokenUSDC).approve(circleTokenMessengerAddress, balanceUsdc);

        ITokenMessenger(circleTokenMessengerAddress).depositForBurn(
            balanceUsdc,
            destinationChainCircle,
            destinationAddress,
            tokenUSDC
        );
    }

    function withdraw(Client.Any2EVMMessage memory _any2EvmMessage) public {
        (
            uint8 command,
            address transferToUser,
            uint256 shares,
            uint256 aWrpTotalSupply,
            uint256 aUsdcCheckpointReference
        ) = abi.decode(
                _any2EvmMessage.data,
                (uint8, address, uint256, uint256, uint256)
            );

        address pool = _getPool();

        /// TESTING ///
        uint256 amount = ((shares * 10 ** 18) * aUsdcCheckpointReference) /
            aWrpTotalSupply;

        IERC20(tokenAUSDC).approve(pool, amount / 10 ** 18);
        IPool(pool).withdraw(tokenUSDC, amount / 10 ** 18, transferToUser);
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            abi.decode(any2EvmMessage.sender, (address)) == MASTER_CONTRACT,
            "MASTER CONTRACT ONLY"
        );
        require(
            any2EvmMessage.sourceChainSelector == MASTER_CHAIN,
            "MASTER CHAIN ONLY"
        );

        uint8 command = internalMessageRouter(any2EvmMessage);

        if (command == 0) {
            warpAssets(any2EvmMessage);
        } else if (command == 1) {
            withdraw(any2EvmMessage);
        } else {
            revert("invalid command from Master");
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector // fetch the source chain identifier (aka selector)
        );
    }

    function _sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory _data
    ) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage;

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: _data, // ABI-encoded string
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
        require(isNodeActive, "Node is not active");
        address pool = _getPool();

        uint256 totalAusdcNode = IERC20(tokenAUSDC).balanceOf(address(this));

        IERC20(tokenUSDC).approve(pool, amount);
        IPool(pool).deposit(tokenUSDC, amount, address(this), 0);

        uint8 command = 0;
        bytes memory data = abi.encode(
            command,
            msg.sender,
            amount,
            totalAusdcNode
        );

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, data); // Send balance to master contract
    }

    function testingReturnFunds() public {
        uint256 balance = IERC20(tokenAUSDC).balanceOf(address(this));

        address pool = _getPool();

        IERC20(tokenAUSDC).approve(pool, balance);
        IPool(pool).withdraw(tokenUSDC, balance, msg.sender);
    }
}
