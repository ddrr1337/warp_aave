// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface INode {
    function withdrawFromSameChain(
        address transferToUser,
        uint256 shares
    ) external;
}
