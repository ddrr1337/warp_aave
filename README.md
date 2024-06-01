## Welcome to Warp Yield

A project created with Brownie v1.20.2

Warp Yield is a protocol aimed at helping users maintain their capital in the highest yield among the blockchains where AAVE operates.

For more detailed information on how the protocol works, please click here: [warpyield.com/docs/basics](https://warpyield.com/docs/basics)

In the `contracts` folder, you will find the main contracts of the protocol. These are:

- `MasterNode.sol`
- `Node.sol`

Also, in the `contracts` folder, you will find several accessory contracts:

- `Bridge.sol`: This contract has no impact on the Protocol and is only used to facilitate the transfer of USDC on the same platform, in addition to generating a fee to support the project.
- `UniswapV3Liquidity.sol`: This is a nearly literal copy of the example from the Solidity docs for adding liquidity to a Uniswap V3 pool. This contract is necessary in testnets in case liquidity needs to be provided in the USDC/WETH pools so that the protocol can purchase the necessary fees. I have already provided some liquidity for testing purposes, so currently, this contract is not necessary.
- `UniswapV3SingleHopSwap.sol`: Same as before this contract is only for help swaping assets in Uniswap pools to ensure pools have enought WETH liquidity.

This repository provides 3 main scripts:

1. `Deploy.py`: This script will deploy the entire protocol and approve the nodes for normal use.

2. `warp_assets.py`: This script provides a way to warp assets from the vault of one blockchain to another. Currently, the `bool public isProtocolInTestMode = true;` found in `MasterNode.sol` allows warping to other chains without having to meet the necessary conditions of interest rates, expiration of information, and others.

3. `action_path.py`: This is a combination of the previous 2 scripts but with the functions separated to call them individually.

The next scripts not affect the protocol, but are needed in case sepolia uinswap V3 pools chains have not enought liquidity. This is of course not necessary on the mainnets, as the Uniswap V3 pools have millions of USDC/WETH in liquidity.

4. `bridge.py`: Script to help to deploy bridges in multiples chains.
5. `add_liquidity_if_needed.py` and `swap_assets.py` are just scripts to manage liquidity to ensure the pools have enought WETH in order Warp Yield can pay Chainlink fees.
