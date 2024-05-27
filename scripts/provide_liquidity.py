from brownie import interface, config, network
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from datetime import datetime


def get_eth_amount(usdc_address, weth_address, usdc_amount):

    uniswap_router = interface.IUniswapV2Router02(
        config["networks"][network.show_active()].get("uniswap_V2_router")
    )
    path = [usdc_address, weth_address]
    amounts = uniswap_router.getAmountsOut(usdc_amount, path)
    print("usdc", amounts[0], amounts[0] / 10**6)
    print("eth", amounts[1], amounts[1] / 10**18)
    return amounts[-1]


def provide_liquidity(account):
    uniswap_router_address = config["networks"][network.show_active()][
        "uniswap_v2_router"
    ]
    usdc_address = config["networks"][network.show_active()]["usdc_circle_token"]
    weth_address = config["networks"][network.show_active()]["weth"]

    uniswap_router = interface.IUniswapV2Router02(uniswap_router_address)
    usdc = interface.IERC20(usdc_address)

    usdc_amount = 200 * 10**6
    eth_amount = get_eth_amount(usdc_address, weth_address, usdc_amount)

    usdc.approve(
        uniswap_router_address,
        usdc_amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )

    tx = uniswap_router.addLiquidityETH(
        usdc_address,
        usdc_amount,
        0,
        0,
        account.address,
        int(datetime.now().timestamp()) + 1000,
        {"from": account, "value": eth_amount, "gas_price": get_gas_price() * 1.5},
    )
    tx.wait(1)
    print(f"Liquidez añadida: {usdc_amount / 10**6} USDC y {eth_amount / 10**18} ETH")


def main():

    get_eth_amount(
        config["networks"][network.show_active()]["usdc_circle_token"],
        config["networks"][network.show_active()]["weth"],
        100 * 10**6,
    )

    print(get_account(account="main").balance() / 10**18)

    print("-----------------------  END SCRIPT -----------------------")
