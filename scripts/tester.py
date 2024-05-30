from brownie import MasterNode, Node, Tester, config, network, interface
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from eth_abi import encode
from datetime import datetime


def balance_WETH(account):
    contract = interface.IERC20(config["networks"][network.show_active()].get("weth"))
    balance = contract.balanceOf(account)
    print(balance)


def deploy_tester():
    deploy = Tester.deploy(
        config["networks"][network.show_active()].get("uniswap_V3_router"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    usdc_interface = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    transfer = usdc_interface.transfer(
        Tester[-1].address,
        3 * 10**6,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def swap():
    contract = Tester[-1]
    swap_ = contract.swap(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def get_token():
    contract = interface.IUniswapV2Pair("0x35E5FB5a1bC92cEd31Ad2C1A4ab2eD6f854349a0")
    token0 = contract.token0()
    print("Tokne0", token0)


def main():
    # deploy_tester()
    # swap()
    balance_WETH(get_account(account="main"))
    # get_token()
    print()
    print()

    print("------------------------END SCRIPT-------------------------------")
