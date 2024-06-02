## Welcome to Warp Yield

A project created with Brownie v1.20.2

**THIS PROJECT IS NOT AUDITED YET DO NOT DEPLOY IN MAINNETS WITHOUT A PROPER AUDIT**

Warp Yield is a protocol aimed at helping users maintain their capital in the highest yield among the blockchains where AAVE operates.

For more detailed information on how the protocol works, please click here: [warpyield.com/docs/basics](https://warpyield.com/docs/basics)

In the `contracts` folder, you will find the main contracts of the protocol. These are:

- `MasterNode.sol`
- `Node.sol`

Also, in the `contracts` folder, you will find several accessory contracts:

- `Bridge.sol`: This contract has no impact on the Protocol and is only used to facilitate the transfer of USDC on the same platform, in addition to generating a fee to support the project.
- `UniswapV3Liquidity.sol`: This is a nearly literal copy of the example from the Solidity docs for adding liquidity to a Uniswap V3 pool. This contract is necessary in testnets in case liquidity needs to be provided in the USDC/WETH pools so that the protocol can purchase the necessary fees. I have already provided some liquidity for testing purposes, so currently, this contract is not necessary.
- `UniswapV3SingleHopSwap.sol`: Same as before this contract is only for help swaping assets in Uniswap pools to ensure pools have enought WETH liquidity.

### This repository provides 3 main scripts:

1. `Deploy.py`: This script will deploy the entire protocol and approve the nodes for normal use.

2. `warp_assets.py`: This script provides a way to warp assets from the vault of one blockchain to another. Currently, the `bool public isProtocolInTestMode = true;` found in `MasterNode.sol` allows warping to other chains without having to meet the necessary conditions of interest rates, expiration of information, and others.

3. `action_path.py`: This is a combination of the previous 2 scripts but with the functions separated to call them individually.

The next scripts do not affect the protocol, but are needed in case sepolia uinswap V3 pools chains have not enought liquidity. This is of course not necessary on the mainnets, as the Uniswap V3 pools have millions of USDC/WETH in liquidity.
Before performing any warp, be sure uniswap V3 pools in sepolia testnets have enough liquidity. No needed in mainnets as uniswap has millions in USDC/WETH liquidity.

4. `bridge.py`: Script to help to deploy bridges in multiples chains.
5. `add_liquidity_if_needed.py` and `swap_assets_if_needed.py` are just scripts to manage liquidity to ensure the pools have enought WETH in order Warp Yield can pay Chainlink fees.

### Baiscs of Brownie

As is common in projects with Brownie, create a .env file in the root of the project with this structure:

`export PRIVATE_KEY=<wallet_privete_key>`

To add networks to your environment, you can follow the official Brownie [documentation](https://eth-brownie.readthedocs.io/en/stable/network-management.html)

Then you will be able to start a script for example the deploy script:

```shell
brownie run scripts/deploy.py --network arbitrum_sepolia
```
