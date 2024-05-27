// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import "../interfaces/uniswap_V3/swap/ISwapRouter02.sol";

contract Tester {
    address constant USDC_ADDRESS = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;
    address constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    ISwapRouter02 public iSwapRouter02;

    constructor(address router) {
        iSwapRouter02 = ISwapRouter02(router);
    }

    function swap() external {
        // Approve the router to spend USDC.
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        IERC20(USDC_ADDRESS).approve(address(iSwapRouter02), usdcBalance);

        // Set up the parameters for the swap.
        ISwapRouter02.ExactOutputSingleParams memory params = ISwapRouter02
            .ExactOutputSingleParams({
                tokenIn: USDC_ADDRESS,
                tokenOut: WETH_ADDRESS,
                fee: 500,
                recipient: address(this),
                amountOut: 100000000000000,
                amountInMaximum: usdcBalance, // for testing dont mind slipperage
                sqrtPriceLimitX96: 0
            });

        // Execute the swap.
        iSwapRouter02.exactOutputSingle(params);
        // withdraw WETH to ETH native
    }
}
