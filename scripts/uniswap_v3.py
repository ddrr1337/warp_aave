from brownie import (
    MasterNode,
    Node,
    config,
    network,
    interface,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from eth_abi import encode
from datetime import datetime


def main():

    print()
    print()
    print("------------------------END SCRIPT-------------------------------")
