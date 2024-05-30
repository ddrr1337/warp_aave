// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/ITokenMessenger.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bridge is Ownable {
    address public usdcAddress;
    address public tokenMessengerAddress;

    constructor(address _usdcAddress, address _tokenMessengerAddress) {
        usdcAddress = _usdcAddress;
        tokenMessengerAddress = _tokenMessengerAddress;
    }

    function sendAssetsToBridge(
        uint256 amount,
        uint32 destinationChainId
    ) public {
        require(
            IERC20(usdcAddress).transferFrom(msg.sender, address(this), amount),
            "Failed to transfer usdc"
        );
        require(amount > 1 * 10 ** 6, "minimum amount, more than 1 USDC");

        uint256 finalAmount = amount - 1 * 10 ** 6;

        IERC20(usdcAddress).approve(tokenMessengerAddress, finalAmount);
        ITokenMessenger(tokenMessengerAddress).depositForBurn(
            finalAmount,
            destinationChainId,
            bytes32(abi.encode(msg.sender)),
            usdcAddress
        );
    }

    function collectFees() external onlyOwner {
        uint256 balanceUsdc = IERC20(usdcAddress).balanceOf(address(this));
        IERC20(usdcAddress).transfer(owner(), balanceUsdc);
    }
}
