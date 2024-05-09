// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IUniswapV3Factory.sol";
import "../interfaces/IWETH9.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IPoolAddressesProvider.sol";

import "./utils_node/UtilsNode.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/// @title - A simple messenger contract for transferring/receiving tokens and data across chains.
contract Node is CCIPReceiver, OwnerIsCreator, UtilsNode {
    using SafeERC20 for IERC20;

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowed(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    IERC20 private s_linkToken;

    /// TESTER ////
    uint64 public immutable MASTER_CONTRACT_CHAIN_ID;
    address public immutable MASTER_CONTRACT_ADDRESS;
    address public immutable POOL_ADDRESS_PROVIDER_ADDRESS;
    address public immutable POOL_DATA_PROVIDER_ADDRESS;
    address public immutable USDC_ADDRESS;
    address public immutable aUSDC_ADDRESS;
    address public immutable WETH_ADDRESS;

    uint256 public aWrpTotalSupplyNodeSide;

    uint public testerFeeTracker;
    bool public isWarping;
    mapping(address => uint256) public avaliableForRefund;

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(
        address _router,
        address _link,
        address _USDC_ADDRESS,
        address _aUSDC_ADDRESS,
        address _WETH_ADDRESS,
        uint64 _MASTER_CONTRACT_CHAIN_ID,
        address _MASTER_CONTRACT_ADDRESS,
        address _POOL_ADDRESS_PROVIDER_ADDRESS,
        address _POOL_DATA_PROVIDER_ADDRESS
    ) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        USDC_ADDRESS = _USDC_ADDRESS;
        aUSDC_ADDRESS = _aUSDC_ADDRESS;
        WETH_ADDRESS = _WETH_ADDRESS;
        MASTER_CONTRACT_CHAIN_ID = _MASTER_CONTRACT_CHAIN_ID;
        MASTER_CONTRACT_ADDRESS = _MASTER_CONTRACT_ADDRESS;
        POOL_ADDRESS_PROVIDER_ADDRESS = _POOL_ADDRESS_PROVIDER_ADDRESS;
        POOL_DATA_PROVIDER_ADDRESS = _POOL_DATA_PROVIDER_ADDRESS;

        allowlistedDestinationChains[_MASTER_CONTRACT_CHAIN_ID] = true;
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////////////RECEIVING MESSAGE///////////////////////////
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

        _sendMessage(
            _destinationChainSelector,
            _receiver,
            data,
            USDC_ADDRESS,
            usdcwithdrawn,
            true
        );
    }

    function _withdraw(Client.Any2EVMMessage memory _any2EvmMessage) internal {
        (, address transferToUser, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint256)
        );

        address pool = _getPool(POOL_ADDRESS_PROVIDER_ADDRESS);
        uint256 totalAusdc = IERC20(aUSDC_ADDRESS).balanceOf(address(this));

        /// TESTING ///
        uint256 amount = ((shares * 10 ** 18) * totalAusdc) /
            aWrpTotalSupplyNodeSide;

        aWrpTotalSupplyNodeSide -= shares;

        if (isWarping) {
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

    /////////////// ONLY FOR TESTING ////////////////////////
    function warpAssets(
        uint64 _destinationChainSelector,
        address _receiver
    ) public {
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

        isWarping = true;
        _sendMessage(
            _destinationChainSelector,
            _receiver,
            data,
            USDC_ADDRESS,
            usdcwithdrawn,
            true
        );
    }

    function _allocateAssetsAndSetAWRPSupply(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        (, uint256 _aWrpSupplyFromOldNode) = abi.decode(
            _any2EvmMessage.data,
            (uint8, uint256)
        );

        _assetsAllocationDeposit(POOL_ADDRESS_PROVIDER_ADDRESS, USDC_ADDRESS);
        aWrpTotalSupplyNodeSide = _aWrpSupplyFromOldNode;

        uint8 command = 1;
        isWarping = false;

        bytes memory data = abi.encode(command);

        _sendMessage(
            MASTER_CONTRACT_CHAIN_ID,
            MASTER_CONTRACT_ADDRESS,
            data,
            address(0),
            0,
            true
        );
    }

    /////////////////////////////////////////////////////////////////////////
    //////////////////////////INCOMING MESAGE HANDLER///////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        uint8 command = _internalCommandRouter(any2EvmMessage);

        if (command == 0) {
            _withdraw(any2EvmMessage);
        } else if (command == 1) {
            _warpAssets(any2EvmMessage);
        } else if (command == 2) {
            _allocateAssetsAndSetAWRPSupply(any2EvmMessage);
        } else {
            revert("invalid command from Node");
        }
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////OUTGOING MESAGES HANDLER///////////////////////
    ///////////////////////////////////////////////////////////////////////

    /// ADD MODIFIERS!! ///

    function _sendMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        bool isPayingNative
    ) internal returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(linkToken) means fees are paid in LINK
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
            _amount,
            tokenFee
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        //////////// TESTING /////////////////
        testerFeeTracker = fees;

        if (isPayingNative) {
            IWETH9(WETH_ADDRESS).withdraw(fees);
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
            s_linkToken.approve(address(router), fees);
        }

        // approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
        if (_token != address(0)) {
            IERC20(_token).approve(address(router), _amount);
        }

        // Send the message through the router and store the returned message ID
        if (isPayingNative) {
            messageId = router.ccipSend{value: fees}(
                _destinationChainSelector,
                evm2AnyMessage
            );
        } else {
            messageId = router.ccipSend(
                _destinationChainSelector,
                evm2AnyMessage
            );
        }

        // Return the message ID
        return messageId;
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _data The bytes data to be sent.
    /// @param _token The token to be transferred.
    /// @param _amount The amount of the token to be transferred.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
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
    //////////////////////////////SENDING MESSAGES//////////////////////////
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
            !isWarping,
            "Asets are Warping Now, deposits on new blockchain"
        );

        uint256 totalAusdcNode = IERC20(aUSDC_ADDRESS).balanceOf(address(this));
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

        _sendMessage(
            MASTER_CONTRACT_CHAIN_ID,
            MASTER_CONTRACT_ADDRESS,
            data,
            address(0),
            0,
            false
        );
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////////   UTILS   ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    // FACTORIZE THIS!!
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
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(destinationCCIPid, evm2AnyMessage);
        return fees;
    }

    function testerRecoverFunds() external onlyOwner {
        uint256 balance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        IERC20(USDC_ADDRESS).transfer(msg.sender, balance);
        uint256 balanceWETH = IERC20(WETH_ADDRESS).balanceOf(address(this));
        IERC20(WETH_ADDRESS).transfer((msg.sender), balanceWETH);
        uint256 ethBalance = address(this).balance;
        msg.sender.call{value: ethBalance}("");
        uint256 linkBalance = s_linkToken.balanceOf(address(this));
        s_linkToken.transfer(msg.sender, linkBalance);
    }
}
