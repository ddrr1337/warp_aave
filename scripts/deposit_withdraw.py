""" SCRIPT TO HELP DEPOSIT USDC AND WITHDRAW aWRP """

from brownie import MasterNode, Node, config, network
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20


def approve_link(spender, amount, account):
    approve_erc20(
        spender,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def approve_circle_usdc_on_node(amount, account):
    approve_erc20(
        Node[-1],
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def withdraw(shares, account):
    approve_link(MasterNode[-1], 10 * 10**18, account)
    contract = MasterNode[-1]
    withdraw_assets = contract.withdraw(
        shares, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def deposit_node(amount, account):
    approve_link(Node[-1], 10 * 10**18, account)
    approve_circle_usdc_on_node(amount, account)
    contract = Node[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def main():
    """DO NOT CALL BOTH"""
    """WITHDRAW NEEDS FIRST THE DEPOSIT AWRP TOKENS COMPLETE PROPAGATION TO MASTER NODE"""

    deposit_node(5 * 10**6, get_account(account="main"))  # called optimistic

    withdraw(
        2 * 10**18,
        get_account(account="main"),
    )  # called in Arbitrum

    print()
    print()

    print("------------------------END SCRIPT-------------------------------")
