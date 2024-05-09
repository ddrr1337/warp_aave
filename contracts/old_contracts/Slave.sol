// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/ITokenMessenger.sol";
import "../../interfaces/IMessageTransmitter.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/IPoolDataProvider.sol";
import "../../interfaces/ISwapRouter02.sol";
import "../../interfaces/IUniswapV3Factory.sol";

contract Slave is CCIPReceiver {
    event Deposit(address indexed from, uint256 amount, uint256 timestamp);
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

    uint64 public immutable MASTER_CHAIN; // harcoded sepolia id_cain CCIP
    uint64 public immutable SLAVE_CHAIN;
    address public immutable MASTER_CONTRACT;
    address public immutable POOL_ADDRESS_PROVIDER_ADDRESS;
    address public immutable POOL_DATA_PROVIDER_ADDRESS;

    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    address public tokenUSDC;
    address public tokenAUSDC;

    address public circleTokenMessengerAddress;
    address public circleMessageTansmiterAddress;

    //NODE STATUS
    bool public isNodeActive = false;
    bool public areAssetsClaimed = false;
    bool public isAWRPTotalSupplySetted = false;

    ////////////////////TESTER ////////////////////////

    uint256 public aWrpTotalSupplySlaveView;

    bool public isWarping;

    mapping(address => uint256) public avaliableForRefund;

    ////////////////////////// CONSTRUCTOR ///////////////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract (CCIP chainlink router).
    /// @param _link The address of the LINK token contract.
    /// @param _tokenUSDC The address of the Circle USDC token contract.
    /// @param _tokenAUSDC The address of the ausdc provided by aave when deposit is done.
    /// @param _circleTokenMessengerAddress The address of the Circle token messenger contract.
    /// @param _POOL_ADDRESS_PROVIDER_ADDRESS The address of the Pool address provider contract (aave).
    /// @param _POOL_DATA_PROVIDER_ADDRESS The address of the Pool data provider contract (aave).
    /// @param _MASTER_CONTRACT The address of the master contract.

    constructor(
        address _router,
        address _link,
        address _tokenUSDC,
        address _tokenAUSDC,
        address _circleTokenMessengerAddress,
        address _circleMessageTansmiterAddress,
        address _POOL_ADDRESS_PROVIDER_ADDRESS,
        address _POOL_DATA_PROVIDER_ADDRESS,
        address _MASTER_CONTRACT,
        uint64 _MASTER_CHAIN,
        uint64 _SLAVE_CHAIN
    ) CCIPReceiver(_router) {
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);

        tokenUSDC = _tokenUSDC;
        tokenAUSDC = _tokenAUSDC;
        circleTokenMessengerAddress = _circleTokenMessengerAddress;
        circleMessageTansmiterAddress = _circleMessageTansmiterAddress;
        POOL_ADDRESS_PROVIDER_ADDRESS = _POOL_ADDRESS_PROVIDER_ADDRESS;
        MASTER_CONTRACT = _MASTER_CONTRACT;
        POOL_DATA_PROVIDER_ADDRESS = _POOL_DATA_PROVIDER_ADDRESS;
        MASTER_CHAIN = _MASTER_CHAIN;
        SLAVE_CHAIN = _SLAVE_CHAIN;
    }

    function _internalCommandRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));

        return command;
    }

    function warpAssets(Client.Any2EVMMessage memory _any2EvmMessage) public {
        // halt deposits????
        isNodeActive = false;
        (
            ,
            uint32 newNodeChainId,
            uint64 newNodeChainIdCCIP,
            bytes32 newNodeReceiver
        ) = abi.decode(_any2EvmMessage.data, (uint8, uint32, uint64, bytes32));

        uint256 usdcwithdrawn = _assetsAllocationWithdraw();

        IERC20(tokenUSDC).approve(circleTokenMessengerAddress, usdcwithdrawn);

        ITokenMessenger(circleTokenMessengerAddress).depositForBurn(
            usdcwithdrawn,
            newNodeChainId,
            newNodeReceiver,
            tokenUSDC
        );

        _sendAWRPTotalSupply(
            newNodeChainIdCCIP,
            address(uint160(uint256(newNodeReceiver)))
        );
    }

    function _sendAWRPTotalSupply(
        uint64 chainCCIPid,
        address nodeAddressReceiver
    ) internal {
        uint8 command = 2;
        bytes memory data = abi.encode(command, aWrpTotalSupplySlaveView);

        _sendMessage(chainCCIPid, nodeAddressReceiver, data);
    }

    function _assetsAllocationWithdraw() internal returns (uint256) {
        uint256 balanceAusdcNode = IERC20(tokenAUSDC).balanceOf(address(this));
        address pool = _getPool();

        IERC20(tokenAUSDC).approve(pool, balanceAusdcNode);

        return IPool(pool).withdraw(tokenUSDC, balanceAusdcNode, address(this));
    }

    function setAWRPTotalSupply(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) public {
        //resume Deposits:

        (, uint256 _aWrpTotalSupplySlaveView) = abi.decode(
            _any2EvmMessage.data,
            (uint8, uint256)
        );

        aWrpTotalSupplySlaveView = _aWrpTotalSupplySlaveView;

        isAWRPTotalSupplySetted = true;
        if (areAssetsClaimed) {
            isNodeActive = true;
        }
    }

    function withdraw(Client.Any2EVMMessage memory _any2EvmMessage) public {
        (, address transferToUser, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint256)
        );

        address pool = _getPool();
        uint256 totalAusdc = IERC20(tokenAUSDC).balanceOf(address(this));

        /// TESTING ///
        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplySlaveView;

        aWrpTotalSupplySlaveView -= shares;

        if (isWarping) {
            avaliableForRefund[transferToUser] += shares;
        } else {
            IERC20(tokenAUSDC).approve(pool, amount / 10 ** 18);
            IPool(pool).withdraw(tokenUSDC, amount / 10 ** 18, transferToUser);
        }
    }

    //FRONTEND UTIL NO CONTRACT USE
    function calculateSharesValue(
        uint256 shares
    ) external view returns (uint256) {
        uint256 totalAusdc = IERC20(tokenAUSDC).balanceOf(address(this));
        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplySlaveView;

        return amount / 10 ** 18;
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        uint8 command = _internalCommandRouter(any2EvmMessage);

        if (command == 0) {
            warpAssets(any2EvmMessage);
        } else if (command == 1) {
            withdraw(any2EvmMessage);
        } else if (command == 2) {
            setAWRPTotalSupply(any2EvmMessage);
        } else {
            revert("invalid command from Master");
        }

        /* emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector // fetch the source chain identifier (aka selector)
        ); */
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
            receiver,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    function _getPool() internal view returns (address) {
        address pool = IPoolAddressesProvider(POOL_ADDRESS_PROVIDER_ADDRESS)
            .getPool();

        return pool;
    }
    // Add referal code as parameter in case in the future activates again

    function deposit(uint256 amount) external {
        require(
            IERC20(tokenUSDC).transferFrom(msg.sender, address(this), amount),
            "Failed to transfer amount"
        );
        require(isNodeActive, "Node is not active");

        uint256 totalAusdcNode = IERC20(tokenAUSDC).balanceOf(address(this));

        uint256 shares;
        if (aWrpTotalSupplySlaveView == 0) {
            shares = amount * 10 ** 12;
        } else {
            shares = (amount * aWrpTotalSupplySlaveView) / totalAusdcNode;
        }
        bytes memory data = abi.encode(uint8(0), msg.sender, shares);

        aWrpTotalSupplySlaveView += shares;

        address pool = _getPool();
        IERC20(tokenUSDC).approve(pool, amount);
        IPool(pool).deposit(tokenUSDC, amount, address(this), 0);

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, data);
        emit Deposit(msg.sender, shares, block.timestamp);
    }

    function refundWithdraw() external {
        uint256 shares = avaliableForRefund[msg.sender];
        bytes memory data = abi.encode(uint8(0), msg.sender, shares);

        avaliableForRefund[msg.sender] = 0;

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, data);
    }

    function sendAaveData(
        bool isActiveNode,
        uint64 destinationNodeCCIPid,
        address destinationNodeAddress
    ) external {
        (
            ,
            ,
            uint256 totalUsdcSupply,
            ,
            uint256 totalUsdcBorrow,
            uint256 supplyRate,
            ,
            ,
            ,
            ,
            ,

        ) = IPoolDataProvider(POOL_DATA_PROVIDER_ADDRESS).getReserveData(
                tokenUSDC
            );

        uint256 linkFeeSendData;

        if (isActiveNode) {
            bytes memory dataFees = abi.encode(
                uint8(2),
                aWrpTotalSupplySlaveView
            );
            linkFeeSendData = getLinkFees(
                destinationNodeCCIPid,
                destinationNodeAddress,
                dataFees
            );
        } else {
            linkFeeSendData = 0;
        }

        bytes memory data = abi.encode(
            uint8(1),
            totalUsdcSupply,
            totalUsdcBorrow,
            supplyRate,
            s_linkToken.balanceOf(address(this)),
            linkFeeSendData
        );

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, data);
    }
    function claimAssetsFromBridge(
        bytes calldata message,
        bytes calldata attestation
    ) public {
        require(
            IMessageTransmitter(circleMessageTansmiterAddress).receiveMessage(
                message,
                attestation
            ),
            "failed from circle bridge IMessageTransmitter returned false"
        );
        _assetsAllocationDeposit();
        areAssetsClaimed = true;
        if (isAWRPTotalSupplySetted) {
            isNodeActive = true;
        }
    }

    function _assetsAllocationDeposit() internal {
        uint256 blanceUsdcNode = IERC20(tokenUSDC).balanceOf(address(this));
        address pool = _getPool();

        IERC20(tokenUSDC).approve(pool, blanceUsdcNode);
        IPool(pool).deposit(tokenUSDC, blanceUsdcNode, address(this), 0);
    }

    function _resumeWithdrawsNodeActive() internal {
        bytes memory data = abi.encode(uint8(2));

        _sendMessage(MASTER_CHAIN, MASTER_CONTRACT, data);
    }

    function getLinkFees(
        uint64 destinationCCIPid,
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
        uint256 fees = s_router.getFee(destinationCCIPid, evm2AnyMessage);
        return fees;
    }

    function testingReturnFunds() public {
        uint256 balance = IERC20(tokenAUSDC).balanceOf(address(this));

        address pool = _getPool();

        IERC20(tokenAUSDC).approve(pool, balance);
        IPool(pool).withdraw(tokenUSDC, balance, msg.sender);
    }

    function testingActivateNode() public {
        isNodeActive = true;
        areAssetsClaimed = true;
        isAWRPTotalSupplySetted = true;
    }
}
