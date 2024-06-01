from brownie import MasterNode, Node, config, network, interface, UniswapV3SingleHopSwap
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from datetime import datetime
import math


def deploy_swap_tokens():
    deploy = UniswapV3SingleHopSwap.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("weth"),
        config["networks"][network.show_active()].get("uniswap_V3_router"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def deposit_eth_to_get_weth(account, amount):

    # Interactúa con el contrato WETH para depositar ETH y obtener WETH
    weth = interface.IWETH9(
        config["networks"][network.show_active()].get("weth"),
    )
    tx = weth.deposit(
        {"from": account, "value": amount, "gas_price": get_gas_price() * 1.5}
    )
    tx.wait(1)

    print(f"Wrapped {amount / 10**18} ETH into WETH")


def swap_assets_to_get_USDC(amount, account):

    approve_erc20(
        UniswapV3SingleHopSwap[-1].address,
        amount * 10,
        config["networks"][network.show_active()].get("weth"),
        account,
    )
    contract = UniswapV3SingleHopSwap[-1]
    swap = contract.swapExactInputSingleHop(
        amount, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def main():

    # deploy_swap_tokens()
    # deposit_eth_to_get_weth(get_account(account="main"), 0.1 * 10**18)
    swap_assets_to_get_USDC(0.02 * 10**18, get_account(account="main"))

    print("------------------  END SCRIPT  -----------------------")
