// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IPoolAddressesProvider.sol";
import "../../interfaces/IPoolDataProvider.sol";
import "../../interfaces/IPool.sol";
import "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract UtilsNode {
    function _internalCommandRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));
        return command;
    }

    function _getPool(
        address poolAddressProvider
    ) internal view returns (address) {
        return IPoolAddressesProvider(poolAddressProvider).getPool();
    }

    function _assetsAllocationWithdraw(
        address poolAddressProvider,
        address aUSDCAddress,
        address usdcAddress
    ) internal returns (uint256) {
        uint256 balanceAusdcNode = IERC20(aUSDCAddress).balanceOf(
            address(this)
        );
        address pool = _getPool(poolAddressProvider);

        IERC20(aUSDCAddress).approve(pool, balanceAusdcNode);
        return
            IPool(pool).withdraw(usdcAddress, balanceAusdcNode, address(this));
    }

    function _assetsAllocationDeposit(
        address poolAddressProvider,
        address usdcAddress
    ) internal {
        uint256 balanceUsdcNode = IERC20(usdcAddress).balanceOf(address(this));
        address pool = _getPool(poolAddressProvider);

        IERC20(usdcAddress).approve(pool, balanceUsdcNode);
        IPool(pool).deposit(usdcAddress, balanceUsdcNode, address(this), 0);
    }

    // Gas calculation helping frontend (no impact in contract)
    // Can get nodeAddress calling node.getRouter()

    function getLinkFees(
        uint64 destinationCCIPid,
        address receiver,
        address s_linkTokenAddress,
        address routerAddress,
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
            feeToken: s_linkTokenAddress
        });

        // Get the fee required to send the message
        IRouterClient router = IRouterClient(routerAddress);
        uint256 fees = router.getFee(destinationCCIPid, evm2AnyMessage);
        return fees;
    }

    // frontend quet curent AAVE suply on this node (no impact in contract)
    function getAaveSupplyRate(
        address poolDAtaProvider,
        address usdcAddress
    ) external view returns (uint256) {
        (, , , , , uint256 supplyRate, , , , , , ) = IPoolDataProvider(
            poolDAtaProvider
        ).getReserveData(usdcAddress);

        return supplyRate;
    }
}
