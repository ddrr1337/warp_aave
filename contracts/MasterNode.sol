// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/INode.sol";

/// @title - A simple messenger contract for transferring/receiving tokens and data across chains.
contract MasterNode is CCIPReceiver, OwnerIsCreator, ERC20 {
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationNodeNotValid(address nodeAddress); // Used when the destination address has not been allowlisted by the contract owner.
    error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.

    LinkTokenInterface private s_linkToken;

    uint64 public immutable MASTER_CONTRACT_CHAIN_ID;

    struct ValidNodes {
        bool isValidNode;
        bool isActiveNode;
        uint64 chainCCIPid;
        uint256 lastDataFromAave;
        uint256 totalUsdcSupply;
        uint256 totalUsdcBorrow;
        uint256 supplyRate;
    }

    mapping(address => ValidNodes) public validNodes;

    bool public allowMoreNodes = true;
    address public activeNode;

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(
        address _router,
        address _link,
        uint64 _MASTER_CONTRACT_CHAIN_ID
    ) CCIPReceiver(_router) ERC20("WarpYield", "aWRP") {
        s_linkToken = LinkTokenInterface(_link);
        MASTER_CONTRACT_CHAIN_ID = _MASTER_CONTRACT_CHAIN_ID;
    }

    modifier onlyAllowedNodes(address nodeAddress) {
        if (!validNodes[nodeAddress].isValidNode) {
            revert DestinationNodeNotValid(nodeAddress);
        }
        _;
    }

    modifier masterAndNodeInSameChain() {
        require(
            validNodes[msg.sender].chainCCIPid == MASTER_CONTRACT_CHAIN_ID,
            "Require master and node in same chain"
        );
        _;
    }

    function stopAddingNodes() external onlyOwner {
        allowMoreNodes = false;
    }

    function addValidNode(
        address nodeAddress,
        uint64 chainCCIPid,
        bool isActiveNode
    ) external onlyOwner {
        require(allowMoreNodes, "No more nodes allowed");
        validNodes[nodeAddress].isValidNode = true;
        validNodes[nodeAddress].isActiveNode = isActiveNode;
        validNodes[nodeAddress].chainCCIPid = chainCCIPid;

        if (isActiveNode) {
            activeNode = nodeAddress;
        }
    }

    function internalCommandRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) public returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));

        return command;
    }

    /////////////////////////////////////////////////////////////////////////
    ////////////////////  INCOMING DEPOSIT => MINT aWRP  ///////////////////
    ////////////////////////  COMMAND == 0  ///////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function _aWarpTokenMinter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        (, address userAddress, uint256 shares) = abi.decode(
            _any2EvmMessage.data,
            (uint8, address, uint256)
        );

        _mint(userAddress, shares);
    }

    ///////////////////  DEPOSIT, MASTER AND NODE IN SAME CHAIN  /////////////////

    function aWarpTokenMinterFromSameChain(
        address userAddress,
        uint256 shares
    ) external masterAndNodeInSameChain onlyAllowedNodes(msg.sender) {
        _mint(userAddress, shares);
    }

    /////////////////////////////////////////////////////////////////////////
    //////////////////////  RESUME PROTOCOL OPERATIONS  ////////////////////
    ////////////////////////  COMMAND == 1  ///////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function _resmumeOperations(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .isActiveNode = true;
        activeNode = abi.decode(_any2EvmMessage.sender, (address));
    }

    ///////////  RESUME OPERATIONS, MASTER AND NODE IN SAME CHAIN  //////////

    function _resmumeOperationsFromSameChain()
        external
        masterAndNodeInSameChain
        onlyAllowedNodes(msg.sender)
    {
        validNodes[msg.sender].isActiveNode = true;
        activeNode = msg.sender;
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////  DATA AAVE FROM NODE  ////////////////////////
    ////////////////////////  COMMAND == 2  ///////////////////////////////
    //////////////////////////////////////////////////////////////////////

    function _nodeAaveFeed(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal {
        require(
            validNodes[abi.decode(_any2EvmMessage.sender, (address))]
                .isValidNode,
            "Node is not valid"
        );

        (
            ,
            uint256 totalUsdcSupply,
            uint256 totalUsdcBorrow,
            uint256 supplyRate
        ) = abi.decode(
                _any2EvmMessage.data,
                (uint8, uint256, uint256, uint256)
            );

        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .lastDataFromAave = block.timestamp;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcSupply = totalUsdcSupply;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .totalUsdcBorrow = totalUsdcBorrow;
        validNodes[abi.decode(_any2EvmMessage.sender, (address))]
            .supplyRate = supplyRate;
    }

    ////////////////  DATA AAVE, MASTER AND NODE IN SAME CHAIN  //////////////

    function nodeAaveFeedFromSameChain(
        uint256 totalUsdcSupply,
        uint256 totalUsdcBorrow,
        uint256 supplyRate
    ) external masterAndNodeInSameChain onlyAllowedNodes(msg.sender) {
        validNodes[msg.sender].lastDataFromAave = block.timestamp;
        validNodes[msg.sender].totalUsdcSupply = totalUsdcSupply;
        validNodes[msg.sender].totalUsdcBorrow = totalUsdcBorrow;
        validNodes[msg.sender].supplyRate = supplyRate;
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////  INCOMING MESAGES HANDLER  /////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require(
            validNodes[abi.decode(any2EvmMessage.sender, (address))]
                .isValidNode,
            "Incoming Message not from a valid node"
        );
        uint8 command = internalCommandRouter(any2EvmMessage);
        if (command == 0) {
            _aWarpTokenMinter(any2EvmMessage);
        } else if (command == 1) {
            _resmumeOperations(any2EvmMessage);
        } else if (command == 2) {
            _nodeAaveFeed(any2EvmMessage);
        } else {
            revert("invalid command from Node");
        }
    }

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////  OUTGOING MESAGES HANDLER  /////////////////////
    ///////////////////////////////////////////////////////////////////////

    function _sendMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data
    ) internal onlyAllowedNodes(_receiver) returns (bytes32 messageId) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        // address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _data,
            address(s_linkToken)
        );

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the CCIP message
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        require(
            s_linkToken.transferFrom(msg.sender, address(this), fees),
            "Not provided Link for fees"
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(router), fees);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Return the message ID
        return messageId;
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _data The bytes data to be sent.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _data,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: _data, // ABI-encoded string
                tokenAmounts: new Client.EVMTokenAmount[](0), // The amount and type of token being transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit
                    Client.EVMExtraArgsV1({gasLimit: 2_000_000})
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    /// @notice Fallback function to allow the contract to receive Ether.
    /// @dev This function has no function body, making it a default function for receiving Ether.
    /// It is automatically called when Ether is sent to the contract without any data.
    receive() external payable {}

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////////  WARP ASSETS  //////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function warpAssets(
        uint64 _destinationCCIPid,
        address _destinationNodeAddress
    ) external {
        uint8 commandWarpAssets = 1;

        bytes memory data = abi.encode(
            commandWarpAssets,
            _destinationCCIPid,
            _destinationNodeAddress
        );
        validNodes[activeNode].isActiveNode = false;

        _sendMessage(validNodes[activeNode].chainCCIPid, activeNode, data);
        activeNode = address(0);
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////////  WITHDRAW  ///////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    function withdraw(uint256 shares) external {
        require(validNodes[activeNode].isActiveNode, "Node is not Active");

        require(shares <= balanceOf(msg.sender), "Not enought balance");

        uint8 commandWitdraw = 0;

        bytes memory data = abi.encode(commandWitdraw, msg.sender, shares);

        _burn(msg.sender, shares);

        if (validNodes[activeNode].chainCCIPid == MASTER_CONTRACT_CHAIN_ID) {
            INode(activeNode).withdrawFromSameChain(msg.sender, shares);
        } else {
            _sendMessage(validNodes[activeNode].chainCCIPid, activeNode, data);
        }
    }

    /////////////////////////////////////////////////////////////////////////
    /////////////////////////////   UTILS   ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////

    // get ChainId from active node, only for frontend, no impact in contract
    function getChainIdFromActiveNode() external view returns (uint64) {
        return validNodes[activeNode].chainCCIPid;
    }

    function checkApprovedWarp(
        address _activeNode,
        address destinationNode
    ) public view returns (bool) {
        //require 24 after last warp
        return
            validNodes[_activeNode].isActiveNode == true &&
            validNodes[_activeNode].lastDataFromAave > 0 &&
            validNodes[destinationNode].lastDataFromAave > 0 &&
            validNodes[_activeNode].lastDataFromAave + 3600 > block.timestamp &&
            validNodes[destinationNode].lastDataFromAave + 3600 >
            block.timestamp &&
            validNodes[destinationNode].isValidNode == true &&
            validNodes[destinationNode].isActiveNode == false &&
            validNodes[_activeNode].supplyRate > 0 &&
            validNodes[_activeNode].supplyRate <
            validNodes[destinationNode].supplyRate;
    }

    // get link fees needed, only for frontend no impact in contract
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
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);
        return fees;
    }
}
