// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract UniswapV3SingleHopSwap {
    address public immutable SWAP_ROUTER_02;
    address public immutable WETH;
    address public immutable DAI;
    ISwapRouter02 public immutable router;
    IERC20 public immutable weth;
    IERC20 public immutable dai;

    constructor(address _DAI, address _WETH, address _SWAP_ROUTER_02) {
        SWAP_ROUTER_02 = _SWAP_ROUTER_02;
        WETH = _WETH;
        DAI = _DAI;
        weth = IERC20(_WETH);
        dai = IERC20(_DAI);

        router = ISwapRouter02(SWAP_ROUTER_02);
    }

    function swapExactInputSingleHop(uint256 amountIn) external {
        weth.transferFrom(msg.sender, address(this), amountIn);
        weth.approve(address(router), amountIn);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: DAI,
                fee: 500,
                recipient: msg.sender,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        router.exactInputSingle(params);
    }
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
