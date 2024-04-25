from brownie import (
    Tester,
    config,
    network,
    interface,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20


TESTER_ARBITRUM = "0x28541129a4f502f5532Bc9939453a63EE5719aE1"

message = "0x000000000000000000000003000000000003f0680000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c7d4b196cb0c7b01d743fbc6116a902379c723800000000000000000000000028541129a4f502f5532bc9939453a63ee5719ae100000000000000000000000000000000000000000000000000000000000f42400000000000000000000000004208dc375959b4a68e62272b16c871611b804f59"
attestation = "0x4ec7551303c17abe21733c82fa02d9e83b6c42e5f992f7e4355418e24807b94f3eafc8d147cc851cb88ecfc77fbd354e7e10b6be39e1077e50024d462a0032e91cb444ed6daa4c1fdc9e30ec8610e0db41b6b0c2657eb46f896e087248feb0201f2348737cd50935e4669e02bf73be0682f59d373ead8ec6721e7a7d04d383682b1b"


def deploy_tester():
    contract = Tester.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
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


def send_to_bridge(amount):
    approve_circle_usdc_on_tester(amount, get_account(account="main"))
    contract = Tester[-1]
    send = contract.sendAssetsToBridge(
        amount,
        TESTER_ARBITRUM,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def claim_from_bridge(account):
    contract = Tester[-1]
    claim = contract.claimAssetsFromBridge(
        message, attestation, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def allowance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allow = contract.allowance(account, Tester[-1])
    print(allow)


def usdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print(balance)


def main():
    # deploy_tester()
    # get_pool()
    # get_usdc_balance(Tester[-1].address)
    get_ausdc_balance(Tester[-1].address)
    # approve_circle_usdc_on_tester(1 * 10**6, get_account(account="main"))
    # allowance(get_account(account="main").address)

    # usdc_balance(Tester[-1])

    # send_to_bridge(0.001 * 10**6)
    claim_from_bridge(get_account(account="main"))
    # print(Tester[-1])
    print("-------------------------------------------------------")
    # print("Tester", Tester[-1].address)

    print("-------------------------------------------------------")
