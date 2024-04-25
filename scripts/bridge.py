from brownie import (
    Bridge,
    config,
    network,
    interface,
)
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20


def deploy_bridge():
    contract = Bridge.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    return contract


def approve_circle_usdc_on_tester(amount, account):

    approve_erc20(
        Bridge[-1].address,
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def get_usdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print("usdc Balance: ", balance / 10**6)


def send_to_bridge(amount, destinationChainID, account):
    approve_circle_usdc_on_tester(amount, account)
    contract = Bridge[-1]
    send = contract.sendAssetsToBridge(
        amount,
        destinationChainID,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def allowance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allow = contract.allowance(account, Bridge[-1])
    print(allow)


def multiple_deploy():
    deploy_bridge()
    network.disconnect()
    network.connect("arbitrum_sepolia")
    deploy_bridge()
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_bridge()


def main():
    # deploy_bridge()
    multiple_deploy()
    # print(config.__dict__)
    # get_pool()
    # get_usdc_balance(Bridge[-1].address)

    # allowance(get_account(account="main").address)

    """ send_to_bridge(
        1.1 * 10**6,
        config["networks"]["arbitrum_sepolia"].get("circle_chain_id"),
        get_account(account="main"),
    ) """

    print("-------------------------------------------------------")
    # print("Bridge Contract", Bridge[-1].address)

    print("-------------------------------------------------------")
