""" MAIN SCRIPT TO DEPLOY BRIDGES, THIS HAS NO IMPACT IN THE PROTOCOL """

from brownie import (
    Bridge,
    config,
    network,
)

from utils.helpfull_scripts import get_account, get_gas_price


def deploy_bridge(account):
    contract = Bridge.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )
    return contract


def multiple_deploy(account):
    deploy_bridge(account)
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    deploy_bridge(account)
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_bridge(account)
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("base_sepolia")
    deploy_bridge(account)
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")

    print("------------------ALL DEPLOYS COMPLETED-------------------------------")


def collect_fees(account):
    contract = Bridge[-1]
    collect = contract.collectFees(
        {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def main():
    # deploy_bridge(get_account(account="main"))  # individual deploy
    multiple_deploy(get_account(account="main"))  # call first on sepolia

    # collect_fees(get_account(account="main"))

    print("-------------------------------------------------------")

    print("------------------  END SCRIPT  -------------------------")
