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
from .action_path import (
    OPTIMISTIC_NODE,
    BASE_NODE,
    MASTER_CONTRACT_ARBITRUM,
)


def aWRP_balance(account):
    contract = MasterNode[-1]
    balance = contract.balanceOf(account)
    print("Balance of aWRP:", balance, balance / 10**18)


def aWrp_total_supply_node():
    contract = Node[-1]
    total_supply = contract.aWrpTotalSupplyNodeSide()
    print("Balance aWRP Node", total_supply, total_supply / 10**18)


def aWrp_total_supply_master():
    contract = MasterNode[-1]
    total_supply = contract.totalSupply()
    print("Balance aWRP Master", total_supply, total_supply / 10**18)


def get_node_data(nodeAddress):
    contract = MasterNode[-1]
    node_data = contract.validNodes(nodeAddress)
    print("Is Node Valid: ", node_data[0])
    print("Is Node Active: ", node_data[1])
    print("Node ChainCCIPid: ", node_data[2])
    print(
        "Node TimeData: ",
        node_data[3],
        "Is Valid, ontime: ",
        (node_data[3] + 3600) > datetime.now().timestamp(),
    )
    print("Node toal usdc supply: ", node_data[4])
    print("Node total usdc borrow: ", node_data[5])
    print("Node supply ratio: ", node_data[6])


def get_nodes_data():
    print()
    print("----------------------ARBITRUM---------------------------")
    get_node_data(OPTIMISTIC_NODE)
    print()
    print("----------------------OPTIMISTIC---------------------------")
    get_node_data(BASE_NODE)


def get_active_node():
    contract = MasterNode[-1]
    active_node = contract.activeNode()
    print(active_node)
    print(active_node == OPTIMISTIC_NODE)


def get_active_nmodes_from_nodes(index):
    contract = Node[-1]
    node_allowed = contract.allowedNodes(index)
    print(node_allowed)


def get_active_node():
    contract = MasterNode[-1]
    active_node = contract.activeNode()
    print(active_node)


def get_chain_CCIPidActiveNode():
    contract = MasterNode[-1]
    chainId = contract.getChainIdFromActiveNode()
    print("ChainID from active node", chainId)


def calculateWithdraw():
    contract = Node[-1]
    result = contract.calculateSharesValue(3 * 10**18)
    print(result)


def main():

    # aWrp_total_supply_node()  # call on Nodes
    # aWrp_total_supply_master()  # call on naster
    # aWRP_balance(get_account(account="main"))  # call on naster
    # get_nodes_data()
    # get_active_node()
    # get_active_nmodes_from_nodes(1)
    # get_active_node()
    # get_chain_CCIPidActiveNode()
    calculateWithdraw()

    print()
    print()

    print("------------------------END SCRIPT-------------------------------")
