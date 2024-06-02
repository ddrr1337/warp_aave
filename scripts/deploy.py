""" SCRIPT TO DEPLOY AND SETUP MASTER AND NODES CONTRACTS """

from brownie import (
    MasterNode,
    Node,
    config,
    network,
)
from utils.helpfull_scripts import get_account, get_gas_price


def deploy_master():
    deploy = MasterNode.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("BC_identifier"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def add_valid_node_on_master(address, chainCCIPid, isActiveNode):
    contract = MasterNode[-1]
    add_node = contract.addValidNode(
        address,
        chainCCIPid,
        isActiveNode,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def stop_adding_nodes_to_master():
    contract = MasterNode[-1]
    stop_adding = contract.stopAddingNodes({"from": get_account(account="main")})


def deploy_node(master_contract_address):
    is_node_active = network.show_active() == "optimistic_sepolia"
    print("Active Node: ", is_node_active)
    deploy = Node.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("ausdc_circle_token"),
        config["networks"][network.show_active()].get("weth"),
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        master_contract_address,
        config["networks"][network.show_active()].get("BC_identifier"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        config["networks"][network.show_active()].get("aave_data_provider"),
        config["networks"][network.show_active()].get("uniswap_V3_router"),
        is_node_active,
        config["networks"][network.show_active()].get("uniswap_pool_fee"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def set_allowed_nodes_in_nodes(deploy_optimistic, deploy_base, deploy_arbitrum):
    contract = Node[-1]
    set_nodes = contract.setAllowedNodes(
        [deploy_optimistic, deploy_base, deploy_arbitrum],
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def set_allowed_nodes_in_all_nodes(deploy_optimistic, deploy_base, deploy_arbitrum):
    set_allowed_nodes_in_nodes(deploy_optimistic, deploy_base, deploy_arbitrum)
    print()
    print(
        "------------------  APPROVED ADDRESSES ON OPTIMISTIC NODE  --------------------"
    )
    network.disconnect()
    network.connect("base_sepolia")
    set_allowed_nodes_in_nodes(deploy_optimistic, deploy_base, deploy_arbitrum)
    print()
    print("------------------  APPROVED ADDRESSES ON BASE NODE  --------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    set_allowed_nodes_in_nodes(deploy_optimistic, deploy_base, deploy_arbitrum)
    print()
    print(
        "------------------  APPROVED ADDRESSES ON ARBITRUM NODE  --------------------"
    )


def add_valid_addresses_in_master_and_nodes(
    deploy_optimistic, deploy_base, deploy_arbitrum
):
    add_valid_node_on_master(
        deploy_optimistic,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        True,
    )
    add_valid_node_on_master(
        deploy_base,
        config["networks"]["base_sepolia"].get("BC_identifier"),
        False,
    )
    add_valid_node_on_master(
        deploy_arbitrum,
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        False,
    )
    stop_adding_nodes_to_master()

    print("------------------  ADDED VAILD ADDRESSES TO MASTER  --------------------")
    network.disconnect()
    network.connect("optimistic_sepolia")
    set_allowed_nodes_in_all_nodes(deploy_optimistic, deploy_base, deploy_arbitrum)
    print()
    print("--------------  ADDED VAILD ADDRESSES TO NODES AND MASTER  ---------------")
    print()


def deploy_master_and_nodes_and_allow_addresses():
    deploy_master()
    master_contract_address = MasterNode[-1].address

    print()
    print("------------------  DEPLOYED MASTER ON ARBITRUM  --------------------")
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_node(master_contract_address)
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_optimistic = Node[-1].address
    print()
    print("------------------  DEPLOYED NODE ON OPTIMISTIC NODE  --------------------")
    network.disconnect()
    network.connect("base_sepolia")
    deploy_node(master_contract_address)
    deploy_base = Node[-1].address
    print()
    print("------------------  DEPLOYED NODE ON BASE NODE  --------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    deploy_node(master_contract_address)
    deploy_arbitrum = Node[-1].address
    print()
    print("------------------  DEPLOYED NODE ON ARBITRUM NODE  --------------------")
    print()

    print("------------------  ALLOWING ADDRESSES  --------------------")
    print()

    add_valid_addresses_in_master_and_nodes(
        deploy_optimistic, deploy_base, deploy_arbitrum
    )
    print(
        "------------------ MASTER AND NODES CONTRACT DEPLOYMENTS --------------------"
    )
    print()
    print()
    print("MASTER CONTRACT ARBITRUM: ", master_contract_address)
    print("OPTIMISTIC NODE: ", deploy_optimistic)
    print("BASE NODE: ", deploy_base)
    print("ARBITRUM NODE: ", deploy_arbitrum)

    print()


def check_var():
    contract = Node[-1]
    test = contract.MASTER_CONTRACT_ADDRESS()
    print("test", test)


def main():
    """MAIN SCRIPT TO DEPLOY AND SETING UP NODES"""
    """ THIS SCRIPT WILL DEPLOY:
        1.- MASTER CONTRACT IN ARBITRUM_SEPOLIA
        2.- NODE IN OPTIMISTIC_SEPOLIA (THIS WILL SETUP AS ACTIVE)
        3.- NODE IN BASE_SEPOLIA
        4.- NODE IN ARBITRUM_SEPOLIA
      """
    deploy_master_and_nodes_and_allow_addresses()  # call this on arbitrum sepolia

    print()
    print()

    print("-------------  MASTER NODE AND NODES DEPLOYED AND SETTED UP  -------------")
