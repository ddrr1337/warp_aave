// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/IPoolAddressesProvider.sol";
import "../../interfaces/IPool.sol";
import "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

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
}
