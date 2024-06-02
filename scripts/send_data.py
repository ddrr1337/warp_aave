"""THIS IS AN EXAMPLE OF SCRIPT TO SEND AAVE DATA FROM NODE TO MASTER"""

"""NOT REQUIRED TO SEND AAVE DATA FRON NODES TO MASTER BECAUSE PROTOCOL IN IN TEST MODE ONLY FOR TESTING"""


from brownie import (
    MasterNode,
    Node,
    config,
    network,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20


def approve_link(amount, account):
    approve_erc20(
        Node[-1],
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def send_data(account):
    approve_link(10 * 10**18, account)
    contract = Node[-1]
    send = contract.sendAaveData({"from": account, "gas_price": get_gas_price() * 1.5})


def main():
    send_data(get_account(account="main"))
    print("--------------------------------------------------------")
