"""THIS IS AN EXAMPLE OF SCRIPT TO SEND AAVE DATA FROM NODE TO MASTER AND CHECK OFFCHAIN IF THE WARP IS APPROVED"""

"""NOT REQUIRED TO SEND AAVE DATA FRON NODES TO MASTER BECAUSE PROTOCOL IN IN TEST MODE ONLY FOR TESTING"""


OPTIMISTIC_NODE = "0x59B13B2CFa3c2519041F76c75BD514f2025fF50d"
BASE_NODE = "0xCB782707E3921443beD6667E9833578EF7dDd35B"
ARBITRUM_SEPOLIA = "0xcfF161Faa743C79ccd15bB982FBd10D2336c0dD7"

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


def check_warp(active_node, destination_node):
    contract = MasterNode[-1]
    check = contract.checkApprovedWarp(active_node, destination_node)
    print(check)


def get_data_nodes(node):
    contract = MasterNode[-1]
    get_data = contract.validNodes(node)
    print("isValidNode", get_data[0])
    print("isActiveNode", get_data[1])
    print("chainCCIPid", get_data[2])
    print("lastDataFromAave", get_data[3])
    print("totalUsdcSupply", get_data[4])
    print("totalUsdcBorrow", get_data[5])
    print("supplyRate", get_data[6])
    print("totalAusdcNode", get_data[7])


def main():
    """DONT CALL ALL THIS FUNCTIONS AT ONCE"""
    """FIRST SEND THE ACTIVE_NODE DATA AND THE DESTIANTION DATA"""
    """ THEN CHECK OFFCHAIN IF WARP IS APPROVED """
    """ CAN ALSO CHECK DATA FROM NODES """
    # send_data(get_account(account="main")) # call from nodes chains
    # get_data_nodes(ARBITRUM_SEPOLIA) # call on arbitrum
    # check_warp(OPTIMISTIC_NODE, ARBITRUM_SEPOLIA) # call on arbitrum
    print("--------------------------------------------------------")
