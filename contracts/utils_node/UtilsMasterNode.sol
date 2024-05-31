// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

// Decodes Incomming mesage and retuns command
contract UtilsMasterNode {
    function _internalCommandRouter(
        Client.Any2EVMMessage memory _any2EvmMessage
    ) internal returns (uint8) {
        uint8 command = abi.decode(_any2EvmMessage.data, (uint8));
        return command;
    }

    // Gas calculation helping frontend (no impact in contract)
    // Can get routerAddress calling node.getRouter()

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

    function calculateNewSupplyRates(
        uint256 totalUsdcSupply,
        uint256 totalUsdcBorrow,
        uint256 supplyRate,
        uint256 addCapital
    ) public pure returns (uint256) {
        // Calculate the new total liquidity after adding capital
        uint256 newTotalLiquidity = totalUsdcSupply + addCapital;

        // Calculate the new utilization rate
        uint256 newUtilizationRate = (totalUsdcBorrow * 1e18) /
            newTotalLiquidity;

        // Calculate the new supply rate
        uint256 newSupplyRate = (supplyRate * newUtilizationRate) / 1e18;

        return newSupplyRate;
    }
}
