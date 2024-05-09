from brownie import (
    Master,
    Slave,
    Tester,
    config,
    network,
    interface,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20

from .old_action_path import MASTER_CONTRACT_SEPOLIA, ARBITRUM_NODE, OPTIMISTIC_NODE
from datetime import datetime


def approve_link(instance, amount, account):
    approve_erc20(
        instance.address,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def feed_data_from_slave(instance, account, isActiveNode):
    approve_link(instance, 2 * 10**18, account)
    contract = (instance,)
    feed = contract.sendAaveData(
        isActiveNode,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def get_node_data(node):
    contract = Master[-1]
    data_node = contract.validNodes(node)
    print("data node", data_node)
    print(
        "time_check",
        data_node[3] + 3600 > check_contract_time(),
        "time_left",
        (data_node[3] + 3600) - check_contract_time(),
    )


def check_warp_approval(activeNode, destinationNode):
    contract = Master[-1]
    allowed = contract.checkApprovedWarp(activeNode, destinationNode)
    print("is warp allowed?", allowed)


def warp_assets(
    circleChainId_new_node,
    ccip_chain_id_new_node,
    address_of_new_node,
):
    approve_link(Master[-1], 2 * 10**18, get_account(account="main"))
    contract = Master[-1]
    message_tx = contract.warpAssets(
        circleChainId_new_node,
        ccip_chain_id_new_node,
        address_of_new_node,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )

    print("Tx confirmed:", message_tx)


def tester_activeNode():
    contract = Master[-1]
    active_node = contract.activeNode()
    print(active_node)


def claim_from_bridge(message, attestation, account):
    contract = Slave[-1]
    claim = contract.claimAssetsFromBridge(
        message, attestation, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def get_link_balance(address_link, address_to_check):
    contract = interface.IERC20(address_link)
    balance = contract.balanceOf(address_to_check)

    print("Balance of Link", balance, balance / 10**18)


def main():
    # feed_data_from_slave(Slace[-1],get_account(account="main"), False)
    # get_node_data(ARBITRUM_NODE)
    # tester_activeNode()
    # print(ARBITRUM_NODE)
    # get_node_data(OPTIMISTIC_NODE)
    # check_warp_approval(ARBITRUM_NODE, OPTIMISTIC_NODE)
    # check_contract_time()
    """warp_assets(
        config["networks"]["optimistic_sepolia"].get("circle_chain_id"),
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
    )"""
    """ claim_from_bridge(
        "0x0000000000000003000000020000000000004d070000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d0000000000000000000000001071602877ce3ee12dd40b5de2e9102d9a68beff00000000000000000000000000000000000000000000000000000000000f42410000000000000000000000000c899fdcbec2ac85f19ec25f43dd2532ecbab0d6",
        "0xb2ee9cb9e6b44d786088d2f306a1e7bfcc524c1320e4f95995c26530ba6bbfbd551fa12da12a4871aced9ed8daf2c07a4c9a41708f78da60bb4114f89dd16c631b94a82719de26003d4ce32fe706a6d47614882716db74dc163a3a906d174c8268058a8ae0884d7f6c15094573302fc5ce5e5c55c6b756f1acdd55a04e0bcf69bb1c",
        get_account(account="main"),
    ) """
    get_link_balance(
        config["networks"][network.show_active()].get("link_token"),
        MASTER_CONTRACT_SEPOLIA,
    )

    print("--------------------------------------------------------")
