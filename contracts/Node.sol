// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils_node/UtilsNode.sol";
import "../interfaces/IWETH9.sol";

//uniswap V3
import "../interfaces/uniswap_V3/swap/ISwapRouter02.sol";
//AAVE interfaces
import "../interfaces/IPool.sol";
import "../interfaces/IPoolDataProvider.sol";
//master contract interface
import "../interfaces/IMasterNode.sol";

contract Node is CCIPReceiver, OwnerIsCreator, UtilsNode {
    using SafeERC20 for IERC20;

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.

    event WarpAssets(
        uint64 indexed detinationCCIPid,
        address indexed destinationNodeAddress,
        uint256 indexed amount
    );
    event WarpCompletedNodeReady(uint8 indexed commandResmueOperations);
    event DepositAssets(
        address indexed userAddress,
        uint256 indexed amountUsdc,
        uint256 indexed amountAwrp
    );

    uint256 public maxVaultAmount = 2000000 * 10 ** 6;
    bool public isNodeActive;
    address[] public allowedNodes;

    uint64 public immutable MASTER_CONTRACT_CHAIN_ID;
    address public immutable MASTER_CONTRACT_ADDRESS;
    uint64 public immutable NODE_CONTRACT_CHAIN_ID;
    address public immutable POOL_ADDRESS_PROVIDER_ADDRESS;
    address public immutable POOL_DATA_PROVIDER_ADDRESS;
    address public immutable USDC_ADDRESS;
    address public immutable aUSDC_ADDRESS;
    address public immutable WETH_ADDRESS;
    uint16 public immutable uinswapFeePool;

    IERC20 private s_linkToken;
    ISwapRouter02 public iSwapRouter02;

    uint256 public aWrpTotalSupplyNodeSide;

    mapping(address => uint256) public avaliableForRefund;

    constructor(
        address _router,
        address _link,
        address _USDC_ADDRESS,
        address _aUSDC_ADDRESS,
        address _WETH_ADDRESS,
        uint64 _MASTER_CONTRACT_CHAIN_ID,
        address _MASTER_CONTRACT_ADDRESS,
        uint64 _NODE_CONTRACT_CHAIN_ID,
        address _POOL_ADDRESS_PROVIDER_ADDRESS,
        address _POOL_DATA_PROVIDER_ADDRESS,
        address _UNISWAP_V3_ROUTER02,
        bool _isNodeActive,
        uint16 _uinswapFeePool
    ) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        USDC_ADDRESS = _USDC_ADDRESS;
        aUSDC_ADDRESS = _aUSDC_ADDRESS;
        WETH_ADDRESS = _WETH_ADDRESS;
        MASTER_CONTRACT_CHAIN_ID = _MASTER_CONTRACT_CHAIN_ID;
        MASTER_CONTRACT_ADDRESS = _MASTER_CONTRACT_ADDRESS;
        NODE_CONTRACT_CHAIN_ID = _NODE_CONTRACT_CHAIN_ID;
        POOL_ADDRESS_PROVIDER_ADDRESS = _POOL_ADDRESS_PROVIDER_ADDRESS;
        POOL_DATA_PROVIDER_ADDRESS = _POOL_DATA_PROVIDER_ADDRESS;

        // uniswap interfaces
        iSwapRouter02 = ISwapRouter02(_UNISWAP_V3_ROUTER02);

        isNodeActive = _isNodeActive;
        uinswapFeePool = _uinswapFeePool;
    }

    // set Allowed Nodes, can only be called once!
    function setAllowedNodes(
        address[] memory _allowedNodes
    ) external onlyOwner {
        require(_allowedNodes.length > 0, "You sent an empty array");
        require(allowedNodes.length == 0, "allowedNodes must be empty");
        allowedNodes = _allowedNodes;
    }

    // Internal function to check if an address is in the allowedNodes array
    function isAllowedAddress(
        address _nodeOrMaster
    ) internal view returns (bool) {
        for (uint16 i = 0; i < allowedNodes.length; i++) {
            if (allowedNodes[i] == _nodeOrMaster) {
                return true;
            }
        }
        if (_nodeOrMaster == MASTER_CONTRACT_ADDRESS) {
            return true;
        }
        return false;
    }

    // Modifier to check if msg.sender is in the allowedNodes array
    modifier onlyAllowedAddresses(address senderAddress) {
        require(
            isAllowedAddress(senderAddress),
            "Caller is not an allowed node"
        );
        _;
    }

    modifier masterAndNodeInSameChain() {
        require(
            NODE_CONTRACT_CHAIN_ID == MASTER_CONTRACT_CHAIN_ID,
            "Require master and node in same chain"
        );
        _;
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////
    //////////////////////////  RECEIVING MESSAGES  ///////////////////////
    //////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////
    //////////////////////////  HANDLE WITHDRAW  ///////////////////////////
    ///////////////////////////  COMMAND = 0  /////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function _withdraw(Client.Any2EVMMessage memory _any2EvmMessage) internal {
        (, address transferToUser, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint256)
        );

        address pool = _getPool(POOL_ADDRESS_PROVIDER_ADDRESS);
        uint256 totalAusdc = IERC20(aUSDC_ADDRESS).balanceOf(address(this));

        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplyNodeSide;

        aWrpTotalSupplyNodeSide -= shares;

        if (!isNodeActive) {
            avaliableForRefund[transferToUser] += shares;
        } else {
            IERC20(aUSDC_ADDRESS).approve(pool, amount / 10 ** 18);
            IPool(pool).withdraw(
                USDC_ADDRESS,
                amount / 10 ** 18,
                transferToUser
            );
        }
    }

    /////////////////////  WITHDRAW MASTER AND NODE IN SAME CHAIN  ///////////////////////

    function withdrawFromSameChain(
        address transferToUser,
        uint256 shares
    ) external masterAndNodeInSameChain {
        require(
            msg.sender == MASTER_CONTRACT_ADDRESS,
            "Only Master Contract allowed"
        );

        address pool = _getPool(POOL_ADDRESS_PROVIDER_ADDRESS);
        uint256 totalAusdc = IERC20(aUSDC_ADDRESS).balanceOf(address(this));

        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplyNodeSide;

        aWrpTotalSupplyNodeSide -= shares;

        if (!isNodeActive) {
            avaliableForRefund[transferToUser] += shares;
        } else {
            IERC20(aUSDC_ADDRESS).approve(pool, amount / 10 ** 18);
            IPool(pool).withdraw(
                USDC_ADDRESS,
                amount / 10 ** 18,
                transferToUser
            );
        }
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////  HANDLE WARP ASSETS  //////////////////////////
    ///////////////////////////  COMMAND = 1  //////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _warpAssets(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        (, uint64 _destinationChainSelector, address _receiver) = abi.decode(
            _any2EvmMessage.data,
            (uint8, uint64, address)
        );
        uint256 usdcwithdrawn = _assetsAllocationWithdraw(
            POOL_ADDRESS_PROVIDER_ADDRESS,
            aUSDC_ADDRESS,
            USDC_ADDRESS
        );

        uint8 commandAWRPSupply = 2;
        bytes memory data = abi.encode(
            commandAWRPSupply,
            aWrpTotalSupplyNodeSide
        );

        isNodeActive = false;
        _sendMessage(
            _destinationChainSelector,
            _receiver,
            data,
            USDC_ADDRESS,
            usdcwithdrawn,
            true
        );

        emit WarpAssets(_destinationChainSelector, _receiver, usdcwithdrawn);
    }

    /////////////  WARP ASSETS, MASTER AND NODE IN SAME CHAIN  //////////////
    function warpAssetsFromSameChain(
        uint64 _destinationChainSelector,
        address _receiver
    ) external masterAndNodeInSameChain {
        require(
            msg.sender == MASTER_CONTRACT_ADDRESS,
            "Only Master Contract allowed"
        );
        uint256 usdcwithdrawn = _assetsAllocationWithdraw(
            POOL_ADDRESS_PROVIDER_ADDRESS,
            aUSDC_ADDRESS,
            USDC_ADDRESS
        );

        uint8 commandAWRPSupply = 2;
        bytes memory data = abi.encode(
            commandAWRPSupply,
            aWrpTotalSupplyNodeSide
        );

        isNodeActive = false;
        _sendMessage(
            _destinationChainSelector,
            _receiver,
            data,
            USDC_ADDRESS,
            usdcwithdrawn,
            true
        );

        emit WarpAssets(_destinationChainSelector, _receiver, usdcwithdrawn);
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////  HANDLE RESUME OPERATIONS  ///////////////////////
    ///////////////////////////  COMMAND = 2  //////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _allocateAssetsAndSetAWRPSupply(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        (, uint256 _aWrpSupplyFromOldNode) = abi.decode(
            _any2EvmMessage.data,
            (uint8, uint256)
        );

        // dont need this here because _assetAllocationDeposit is called in _sendMessage
        // I left this line commented and not deleted to understand why is not called here
        //_assetsAllocationDeposit(POOL_ADDRESS_PROVIDER_ADDRESS, USDC_ADDRESS);

        aWrpTotalSupplyNodeSide = _aWrpSupplyFromOldNode;

        uint8 commandResumeOperations = 1;
        isNodeActive = true;

        bytes memory data = abi.encode(commandResumeOperations);

        if (NODE_CONTRACT_CHAIN_ID == MASTER_CONTRACT_CHAIN_ID) {
            // here is needed cuz no message is sent
            _assetsAllocationDeposit(
                POOL_ADDRESS_PROVIDER_ADDRESS,
                USDC_ADDRESS
            );
            IMasterNode(MASTER_CONTRACT_ADDRESS)
                ._resmumeOperationsFromSameChain();
        } else {
            _sendMessage(
                MASTER_CONTRACT_CHAIN_ID,
                MASTER_CONTRACT_ADDRESS,
                data,
                address(0),
                0,
                true
            );
        }

        emit WarpCompletedNodeReady(commandResumeOperations);
    }
    //////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////
    ////////////////////////  INCOMING MESAGE HANDLER  /////////////////////
    /////////////////  THIS FUNC IS CALLED BY CHAINLINK  //////////////////
    //////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    function _ccipReceive(
        Client.Any2EVMMessage memory _any2EvmMessage
    )
        internal
        override
        onlyAllowedAddresses(abi.decode(_any2EvmMessage.sender, (address)))
    {
        uint8 command = _internalCommandRouter(_any2EvmMessage);

        if (command == 0) {
            _withdraw(_any2EvmMessage);
        } else if (command == 1) {
            _warpAssets(_any2EvmMessage);
        } else if (command == 2) {
            _allocateAssetsAndSetAWRPSupply(_any2EvmMessage);
        } else {
            revert("invalid command");
        }
    }
    /////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////
    ///////////////////////  OUTGOING MESSAGES HANDLER  ///////////////////
    //////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

    function _sendMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        bool isPayingNative
    ) internal onlyAllowedAddresses(_receiver) returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(s_linkToken) means fees are paid in LINK
        uint256 newAmount;
        if (_amount > 0) {
            newAmount = _amount;
        }

        address tokenFee;
        if (isPayingNative) {
            tokenFee = address(0);
        } else {
            tokenFee = address(s_linkToken);
        }

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _data,
            _token,
            newAmount,
            tokenFee
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient routerCCIP = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = routerCCIP.getFee(
            _destinationChainSelector,
            evm2AnyMessage
        );

        // When an incoming message requires to pay the fees on native token
        // This will sell some USDC from the vault to get the eth needed to pay the fees
        uint256 amountInUsdc;
        if (isPayingNative) {
            amountInUsdc = _getNativeFees(fees);
            if (newAmount > 0) {
                evm2AnyMessage = _buildCCIPMessage(
                    _receiver,
                    _data,
                    _token,
                    newAmount - amountInUsdc,
                    tokenFee
                );
            }
        }

        if (isPayingNative) {
            if (fees > address(this).balance) {
                revert NotEnoughBalance(address(this).balance, fees);
            }
        } else {
            require(
                s_linkToken.transferFrom(msg.sender, address(this), fees),
                "Not provided Link for fees"
            );
            if (fees > s_linkToken.balanceOf(address(this)))
                revert NotEnoughBalance(
                    s_linkToken.balanceOf(address(this)),
                    fees
                );
            s_linkToken.approve(address(routerCCIP), fees);
        }

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        if (_token != address(0)) {
            IERC20(_token).approve(address(routerCCIP), newAmount);
        }

        // Send the message through the router and store the returned message ID
        if (isPayingNative) {
            messageId = routerCCIP.ccipSend{value: fees}(
                _destinationChainSelector,
                evm2AnyMessage
            );
        } else {
            messageId = routerCCIP.ccipSend(
                _destinationChainSelector,
                evm2AnyMessage
            );
        }

        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        if (usdcBalance > 0) {
            _assetsAllocationDeposit(
                POOL_ADDRESS_PROVIDER_ADDRESS,
                USDC_ADDRESS
            );
        }

        // Return the message ID
        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts;

        if (_token == address(0) && _amount == 0) {
            tokenAmounts = new Client.EVMTokenAmount[](0);
        } else {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: _token,
                amount: _amount
            });
        }
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: _data, // ABI-encoded string
                tokenAmounts: tokenAmounts, // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    Client.EVMExtraArgsV1({gasLimit: 2_000_000})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////
    //////////////////////////  SENDING MESSAGES  //////////////////////////
    ///////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////////   DEPOSIT   ////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function deposit(uint256 amount) external {
        require(
            IERC20(USDC_ADDRESS).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Failed to transfer amount"
        );
        require(
            isNodeActive,
            "Asets are Warping Now, deposits on new blockchain"
        );

        uint256 totalAusdcNode = IERC20(aUSDC_ADDRESS).balanceOf(address(this));
        require(
            totalAusdcNode + amount < maxVaultAmount,
            "Node furfilled no more deposits allowed"
        );
        uint256 shares;
        if (aWrpTotalSupplyNodeSide == 0) {
            shares = amount * 10 ** 12;
        } else {
            shares = (amount * aWrpTotalSupplyNodeSide) / totalAusdcNode;
        }

        aWrpTotalSupplyNodeSide += shares;

        uint8 command = 0;
        bytes memory data = abi.encode(command, msg.sender, shares);

        address pool = _getPool(POOL_ADDRESS_PROVIDER_ADDRESS);
        IERC20(USDC_ADDRESS).approve(pool, amount);
        IPool(pool).deposit(USDC_ADDRESS, amount, address(this), 0);

        if (NODE_CONTRACT_CHAIN_ID == MASTER_CONTRACT_CHAIN_ID) {
            IMasterNode(MASTER_CONTRACT_ADDRESS).aWarpTokenMinterFromSameChain(
                msg.sender,
                shares
            );
        } else {
            _sendMessage(
                MASTER_CONTRACT_CHAIN_ID,
                MASTER_CONTRACT_ADDRESS,
                data,
                address(0),
                0,
                false
            );
        }

        emit DepositAssets(msg.sender, amount, shares);
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////   RECOVER aWRP FROM A FAILED WITHDRAW   ////////////////
    ///////////////////////////////////////////////////////////////////////

    function recoverAWRPFromFailedWithdraw() external {
        require(avaliableForRefund[msg.sender] > 0, "No aWRP tokens to refund");
        uint256 sharesToRefund = avaliableForRefund[msg.sender];

        uint8 commandRefundAWRP = 0; // Same command than deposit
        bytes memory data = abi.encode(
            commandRefundAWRP,
            msg.sender,
            sharesToRefund
        );

        if (NODE_CONTRACT_CHAIN_ID == MASTER_CONTRACT_CHAIN_ID) {
            IMasterNode(MASTER_CONTRACT_ADDRESS).aWarpTokenMinterFromSameChain(
                msg.sender,
                sharesToRefund
            );
        } else {
            _sendMessage(
                MASTER_CONTRACT_CHAIN_ID,
                MASTER_CONTRACT_ADDRESS,
                data,
                address(0),
                0,
                false
            );
        }
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////   SEND DATA NODE TO MASTER   /////////////////////
    ///////////////////////////////////////////////////////////////////////

    function sendAaveData() external {
        (
            ,
            ,
            uint256 totalAToken,
            ,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            ,
            ,
            ,
            ,
            ,

        ) = IPoolDataProvider(POOL_DATA_PROVIDER_ADDRESS).getReserveData(
                USDC_ADDRESS
            );

        uint256 totalAusdcNode = IERC20(aUSDC_ADDRESS).balanceOf(address(this));

        uint8 commandSendAaveData = 2;
        bytes memory data = abi.encode(
            commandSendAaveData,
            totalAToken,
            totalVariableDebt,
            totalVariableDebt,
            totalAusdcNode
        );
        if (NODE_CONTRACT_CHAIN_ID == MASTER_CONTRACT_CHAIN_ID) {
            IMasterNode(MASTER_CONTRACT_ADDRESS).nodeAaveFeedFromSameChain(
                totalAToken,
                totalVariableDebt,
                totalVariableDebt,
                totalAusdcNode
            );
        } else {
            _sendMessage(
                MASTER_CONTRACT_CHAIN_ID,
                MASTER_CONTRACT_ADDRESS,
                data,
                address(0),
                0,
                false
            );
        }
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////////   UTILS   ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _getNativeFees(uint256 fees) internal returns (uint256) {
        // withdraw the usdc from aave for paying the fees
        uint256 ausdcBalance = IERC20(aUSDC_ADDRESS).balanceOf(address(this));
        if (ausdcBalance > 0) {
            _assetsAllocationWithdraw(
                POOL_ADDRESS_PROVIDER_ADDRESS,
                aUSDC_ADDRESS,
                USDC_ADDRESS
            );
        }

        // Approve the router to spend USDC.
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        IERC20(USDC_ADDRESS).approve(address(iSwapRouter02), usdcBalance);

        // Set up the parameters for the swap.
        ISwapRouter02.ExactOutputSingleParams memory params = ISwapRouter02
            .ExactOutputSingleParams({
                tokenIn: USDC_ADDRESS,
                tokenOut: WETH_ADDRESS,
                fee: uinswapFeePool,
                recipient: address(this),
                amountOut: fees,
                amountInMaximum: usdcBalance, // for testing dont mind slipperage
                sqrtPriceLimitX96: 0
            });

        // Execute the swap.
        uint256 amountIn = iSwapRouter02.exactOutputSingle(params);
        IWETH9(WETH_ADDRESS).withdraw(fees);
        return amountIn;
    }

    //frontend stuff, no impcat in contract
    function calculateSharesValue(
        uint256 shares
    ) external view returns (uint256) {
        uint256 totalAusdc = IERC20(aUSDC_ADDRESS).balanceOf(address(this));

        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplyNodeSide;

        return amount / 10 ** 18;
    }
    //END
}
