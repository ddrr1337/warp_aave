// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "../interfaces/IPool.sol";

contract Tester {
    address public usdcAddress;

    constructor(address _usdcAddress) {
        usdcAddress = _usdcAddress;
    }

    function getPool(
        address _PoolAddressesProvider
    ) public view returns (address) {
        address pool = IPoolAddressesProvider(_PoolAddressesProvider).getPool();

        return pool;
    }

    function deposit(uint256 amount, address _PoolAddressesProvider) public {
        require(
            IERC20(usdcAddress).transferFrom(msg.sender, address(this), amount),
            "Not usdt tokens provided"
        );

        address pool = getPool(_PoolAddressesProvider);

        IERC20(usdcAddress).approve(pool, amount);

        IPool(pool).deposit(usdcAddress, amount, address(this), 0);
    }

    function exit() public {
        uint256 balance = IERC20(usdcAddress).balanceOf(address(this));
        IERC20(usdcAddress).transfer(msg.sender, balance);
    }
}
