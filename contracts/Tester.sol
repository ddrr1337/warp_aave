// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IMessageTransmitter.sol";
import "../interfaces/ITokenMessenger.sol";

contract Tester {
    address public usdcAddress;
    uint256 public testerBalance;
    address public poolAddressesProvider; //arbirtum_side

    constructor(address _usdcAddress, address _poolAddressesProvider) {
        usdcAddress = _usdcAddress;
        poolAddressesProvider = _poolAddressesProvider;
    }

    function _getPool() internal view returns (address) {
        address pool = IPoolAddressesProvider(poolAddressesProvider).getPool();

        return pool;
    }

    function sendAssetsToBridge(
        uint256 amount,
        bytes32 destinationAddress
    ) public {
        require(
            IERC20(usdcAddress).transferFrom(msg.sender, address(this), amount),
            "Failed to transfer usdc"
        );
        IERC20(usdcAddress).approve(
            0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5,
            amount
        );
        ITokenMessenger(0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5)
            .depositForBurn(amount, uint32(3), destinationAddress, usdcAddress);
    }

    function claimAssetsFromBridge(
        bytes calldata message,
        bytes calldata attestation
    ) public {
        require(
            IMessageTransmitter(0xaCF1ceeF35caAc005e15888dDb8A3515C41B4872)
                .receiveMessage(message, attestation),
            "failed from circle returning false"
        );
        _assetsAllocation();
    }

    function _assetsAllocation() internal {
        uint256 blanceUsdcNode = IERC20(usdcAddress).balanceOf(address(this));
        address pool = _getPool();

        IERC20(usdcAddress).approve(pool, blanceUsdcNode);
        IPool(pool).deposit(usdcAddress, blanceUsdcNode, address(this), 0);
    }
}
