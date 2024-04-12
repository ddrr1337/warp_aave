from brownie import (
    Tester,
    config,
    network,
    interface,
)
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20


def deploy_tester():
    contract = Tester.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def get_pool():
    aave_pool_addresses_provider_sepolia = config["networks"][
        network.show_active()
    ].get("aave_pool_addresses_provider")

    pool_address = interface.IPoolAddressesProvider(
        aave_pool_addresses_provider_sepolia
    ).getPool()

    print("Aave Pool Address: ", pool_address)
    return pool_address


def approve_circle_usdc_on_tester(amount, account):
    approve_erc20(
        Tester[-1].address,
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def deposit_tester(amount):
    contract = Tester[-1]
    deposit = contract.deposit(
        amount,
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def get_usdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print("usdc Balance: ", balance / 10**6)


def get_ausdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("ausdc_circle_token")
    )
    balance = contract.balanceOf(account)

    print(balance)


def main():
    # deploy_tester()
    # get_pool()
    # get_usdc_balance(get_account(account="main"))
    # approve_circle_usdc_on_tester(1 * 10**6, get_account(account="main"))
    # deposit_tester(1 * 10**6)
    get_ausdc_balance(Tester[-1].address)
    print("-------------------------------------------------------")
    # print("Tester", Tester[-1].address)

    print("-------------------------------------------------------")
