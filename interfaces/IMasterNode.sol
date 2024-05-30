// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMasterNode {
    function aWarpTokenMinterFromSameChain(
        address userAddress,
        uint256 shares
    ) external;

    function nodeAaveFeedFromSameChain(
        uint256 totalUsdcSupply,
        uint256 totalUsdcBorrow,
        uint256 supplyRate
    ) external;

    function _resmumeOperationsFromSameChain() external;
}
