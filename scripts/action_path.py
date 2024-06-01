from brownie import MasterNode, Node, config, network, interface
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20

from brownie.project.flattener import Flattener


MASTER_CONTRACT_ARBITRUM = "0x6b8E782bE5cFB853920762631b0aE3053B14a1da"
OPTIMISTIC_NODE = "0xb502b8B0a67f3346A7bfd3f15BA02962a9560822"
BASE_NODE = "0xc64177A5521B2C5019c315c277522ECE93D8E953"
ARBITRUM_NODE = "0x52E0198455f5432EDDb69a2E9b2ae7F24a0729E5"


def deploy_master():
    deploy = MasterNode.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("BC_identifier"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )


def add_valid_node_on_master(address, chainCCIPid, isActiveNode):
    contract = MasterNode[-1]
    add_node = contract.addValidNode(
        address,
        chainCCIPid,
        isActiveNode,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def deploy_node():
    is_node_active = network.show_active() == "optimistic_sepolia"
    print("Active Node: ", is_node_active)
    deploy = Node.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("ausdc_circle_token"),
        config["networks"][network.show_active()].get("weth"),
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        MASTER_CONTRACT_ARBITRUM,
        config["networks"][network.show_active()].get("BC_identifier"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        config["networks"][network.show_active()].get("aave_data_provider"),
        config["networks"][network.show_active()].get("uniswap_V3_router"),
        is_node_active,
        config["networks"][network.show_active()].get("uniswap_pool_fee"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


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


def set_allowed_nodes_in_nodes():
    contract = Node[-1]
    set_nodes = contract.setAllowedNodes(
        [OPTIMISTIC_NODE, BASE_NODE, ARBITRUM_NODE],
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def set_allowed_nodes_in_all_nodes():
    set_allowed_nodes_in_nodes()
    print()
    print(
        "------------------  APPROVED ADDRESSES ON OPTIMISTIC NODE  --------------------"
    )
    network.disconnect()
    network.connect("base_sepolia")
    set_allowed_nodes_in_nodes()
    print()
    print("------------------  APPROVED ADDRESSES ON BASE NODE  --------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    set_allowed_nodes_in_nodes()
    print()
    print(
        "------------------  APPROVED ADDRESSES ON ARBITRUM NODE  --------------------"
    )


def warp_assets(destinationCCIPid, destinationNodeAddress, account):

    approve_link(MasterNode[-1], 10 * 10**18, account)

    contract = MasterNode[-1]
    warp_assets = contract.warpAssets(
        destinationCCIPid,
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def warp_assets_optimistic(destinationCCIPid, destinationNodeAddress):
    contract = Node[-1]
    warp_assets = contract.warpAssetsTester(
        destinationCCIPid,
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def tester_recover_funds():
    contract = Node[-1]
    return_assets = contract.testerRecoverFunds(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def weth_tester_withdraw(account):
    contract_1 = interface.IERC20(config["networks"][network.show_active()].get("weth"))
    balance = contract_1.balanceOf(account)
    contract = interface.IWETH9(config["networks"][network.show_active()].get("weth"))
    deposit = contract.withdraw(
        balance, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def tester_recover_funds_both():
    tester_recover_funds()
    weth_tester_withdraw(get_account(account="main"))
    network.disconnect()
    network.connect("base_sepolia")
    tester_recover_funds()
    weth_tester_withdraw(get_account(account="main"))


def get_shares(account):
    contract = MasterNode[-1]
    balance = contract.balanceOf(account)
    print(balance)


def swap():
    contract = Node[-1]
    swap_ = contract._getNativeFees(
        100000000000000,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def approve_link_to_node(amount, account):
    approve_erc20(
        Node[-1].address,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def deposit_node(amount, account):

    approve_link_to_node(10 * 10**18, account)
    approve_circle_usdc_on_node(amount, account)
    contract = Node[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def tester_var():
    contract = MasterNode[-1]
    test = contract.activeNode()
    print("test", test)


def main():
    # tester_recover_funds_both()
    # deploy_master()  # deploy on arbitrum
    # deploy_node()

    """add_valid_node_on_master(
        OPTIMISTIC_NODE,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        True,
    )  # called in arbitrum
    add_valid_node_on_master(
        BASE_NODE,
        config["networks"]["base_sepolia"].get("BC_identifier"),
        False,
    )  # called in arbitrum
    add_valid_node_on_master(
        ARBITRUM_NODE,
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        False,
    )"""  # called in arbitrum
    # set_allowed_nodes_in_all_nodes()  # call in optimistic (first active node)
    # deposit_node(5 * 10**6, get_account(account="main"))  # called optimistic
    # tester_var()

    # call on optimistic
    # get_shares(get_account(account="main"))
    """ withdraw(
        200000000000000000000,
        get_account(account="main"),
    ) """

    """ warp_assets(
        config["networks"]["base_sepolia"].get("BC_identifier"),
        "0xf8F04B1015fdCfDE4c41E5377Fe29388BF67e9e8",
        get_account(account="main"),
    ) """  # called on arbitrum
    """ warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        get_account(account="main"),
    )  """  # called on arbitrum

    """ warp_assets_optimistic(
        config["networks"]["base_sepolia"].get("BC_identifier"),
        "0xf8F04B1015fdCfDE4c41E5377Fe29388BF67e9e8",
    ) """
    """ warp_assets_optimistic(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
    ) """
    # swap()

    print()
    print()

    print("------------------------END SCRIPT-------------------------------")
