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


MASTER_CONTRACT_SEPOLIA = "0x16aD724322Bf1b1A7e0B92428Ebf92e3f0b2aC9a"
ARBITRUM_NODE = "0x0F4fE5eD87A867184141645AD70De3F292106Aa3"
OPTIMISTIC_NODE = "0xBeF5a01f90C07372fD91C2ac44c7C51e646bf5d9"
BASE_NODE = ""


def deploy_master():
    deploy = MasterNode.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("BC_identifier"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token"),
    )


def deploy_node(amount, account):
    is_node_active = network.show_active() == "arbitrum_sepolia"
    deploy = Node.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("ausdc_circle_token"),
        config["networks"][network.show_active()].get("weth"),
        config["networks"]["sepolia"].get("BC_identifier"),
        MASTER_CONTRACT_SEPOLIA,
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        config["networks"][network.show_active()].get("aave_data_provider"),
        config["networks"][network.show_active()].get("uniswap_router_02"),
        is_node_active,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )
    link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token"),
    )

    weth_tester_deposit(amount, account)

    transfer_weth(amount, Node[-1].address, account)


"""     amount_link = 0.5
    transfer = link_contract.transfer(
        Node[-1].address,
        amount_link * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print(f"Sent {amount_link}Link to Sender contract") """


def allow_destination_chain(instance, chainName):
    chainCCIPid = config["networks"][chainName].get("BC_identifier")
    contract = instance
    allow_chain = contract.allowlistDestinationChain(
        chainCCIPid,
        True,
        {"from": get_account(account="main"), "gas_prpice": get_gas_price() * 1.5},
    )

    print(f"Allowed chain {chainCCIPid} to contract {instance.address}")


def warp_assets(
    activeCCIPid, activeNodeAddress, destinationCCIPid, destinationNodeAddress, account
):
    link_fees = get_link_fee_warpAssets(activeCCIPid, activeNodeAddress)
    approve_link_to_master(10 * 10**18, account)

    contract = MasterNode[-1]
    warp_assets = contract.warpAssets(
        destinationCCIPid,
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def warp_assets_arbitrum(destinationCCIPid, destinationNodeAddress):
    contract = Node[-1]
    warp_assets = contract.warpAssets(
        destinationCCIPid,
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def balance_usdc(account):
    contract = interface.ERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print("Balance USDC", balance, balance / 10**6)


def balance_ausdc(account):
    contract = interface.ERC20(
        config["networks"][network.show_active()].get("ausdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print("Balance aUSDC", balance, balance / 10**6)


def balance_link(account):
    contract = interface.ERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    balance = contract.balanceOf(account)
    print("Balance LINK", balance, balance / 10**18)


def get_pool_uni():
    contract = interface.IUniswapV3Factory(
        config["networks"][network.show_active()].get("uniswap_V3_factory")
    )
    pool = contract.getPool(
        config["networks"][network.show_active()].get("weth"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        500,
    )
    print(pool)
    return pool


def get_uni_price():
    pool_address = get_pool_uni()
    contract = interface.IUniswapV3Pool(pool_address)

    balance = contract.slot0()
    print(balance)


def weth_tester_deposit(amount, account):
    contract = interface.IWETH9(config["networks"][network.show_active()].get("weth"))
    deposit = contract.deposit(
        {"from": account, "gas_price": get_gas_price() * 1.5, "value": amount}
    )


def weth_tester_withdraw(account):
    contract_1 = interface.IERC20(config["networks"][network.show_active()].get("weth"))
    balance = contract_1.balanceOf(account)
    contract = interface.IWETH9(config["networks"][network.show_active()].get("weth"))
    deposit = contract.withdraw(
        balance, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def transfer_weth(amount, destinationNodeAddress, account):
    contract = interface.IERC20(config["networks"][network.show_active()].get("weth"))
    transfer = contract.transfer(
        destinationNodeAddress,
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def weth_balance(account):
    contract = interface.IERC20(config["networks"][network.show_active()].get("weth"))
    balance = contract.balanceOf(account)
    print("WETH balance", balance, balance / 10**18)


def tester_transfer_eth(amount):
    account = get_account(account="main")
    account.transfer(Node[-1].address, amount, gas_price=get_gas_price() * 1.5)


def tester_recover_funds():
    contract = Node[-1]
    return_assets = contract.testerRecoverFunds(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def tester_recover_funds_both():
    tester_recover_funds()
    weth_tester_withdraw(get_account(account="main"))
    network.disconnect()
    network.connect("optimistic_sepolia")
    tester_recover_funds()
    weth_tester_withdraw(get_account(account="main"))


def get_link_fee(instance, destinationCCIPid):
    contract = instance
    uint8_command = 2

    dummy_bytes = encode(
        ["uint8"],
        [uint8_command],
    )

    get_fee = contract.getLinkFees(destinationCCIPid, OPTIMISTIC_NODE, dummy_bytes)
    print(get_fee / 10**18)
    return get_fee


def get_link_fee_warpAssets(activeCCIPid, activeNodeAddress):
    contract = MasterNode[-1]
    uint8_command = 2
    uint64_destination_chainCCIPid = config["networks"]["optimistic_sepolia"].get(
        "BC_identifier"
    )  # DUMMY DATA
    address_destination_nodeAddress = OPTIMISTIC_NODE  # DUMMY DATA

    dummy_bytes = encode(
        ["uint8", "uint64", "address"],
        [
            uint8_command,
            uint64_destination_chainCCIPid,
            address_destination_nodeAddress,
        ],
    )

    get_fee = contract.getLinkFees(activeCCIPid, activeNodeAddress, dummy_bytes)
    print("Fee for warpAssets: ", get_fee / 10**18)
    return get_fee


def approve_link_to_node(amount, account):
    approve_erc20(
        Node[-1].address,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def approve_link_to_master(amount, account):
    approve_erc20(
        MasterNode[-1].address,
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


def deposit_node(amount, account):
    link_fee = (
        get_link_fee(Node[-1], config["networks"]["sepolia"].get("BC_identifier")) * 1.2
    )
    approve_link_to_node(10 * 10**18, account)
    approve_circle_usdc_on_node(amount, account)
    contract = Node[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def withdraw(activeCCIPid, activeNodeAddress, shares, account):
    link_fees = get_link_fee_warpAssets(activeCCIPid, activeNodeAddress)
    approve_link_to_master(10 * 10**18, account)

    contract = MasterNode[-1]
    withdraw_assets = contract.withdraw(
        shares, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def aWrp_total_supply_node():
    contract = Node[-1]
    total_supply = contract.aWrpTotalSupplyNodeSide()
    print("Balance aWRP Node", total_supply, total_supply / 10**18)


def aWrp_total_supply_master():
    contract = MasterNode[-1]
    total_supply = contract.totalSupply()
    print("Balance aWRP Master", total_supply, total_supply / 10**18)


def aWRP_balance(account):
    contract = MasterNode[-1]
    balance = contract.balanceOf(account)
    print("Balance of aWRP:", balance, balance / 10**18)


def test_usdc_allowance():
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allowance = contract.allowance(get_account(account="main"), ARBITRUM_NODE)
    print(allowance)


def add_valid_node(address, chainCCIPid, isActiveNode):
    contract = MasterNode[-1]
    add_node = contract.addValidNode(
        address,
        chainCCIPid,
        isActiveNode,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


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


def check_var():
    contract = Node[-1]
    var1 = contract.testerParams()

    print(var1)


def send_node_data_to_master(account):
    approve_link_to_node(10 * 10**18, account)
    contract = Node[-1]
    send_data = contract.sendAaveData(
        {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def check_ready_for_warp(activeNodeAddress, destinationNodeAddress):
    contract = MasterNode[-1]
    is_ready = contract.checkApprovedWarp(activeNodeAddress, destinationNodeAddress)

    print(is_ready)


def get_nodes_data():
    get_node_data(ARBITRUM_NODE)
    print()
    print("----------------------ARBITRUM---------------------------")
    get_node_data(OPTIMISTIC_NODE)
    print()
    print("----------------------OPTIMISTIC---------------------------")


def main():
    # tester_recover_funds_both()  # call on arbitrum
    # deploy_master()  # call on sepolia
    deploy_node(
        0.1 * 10**18, account=get_account(account="main")
    )  # 2 calls arbitrum, optimistic

    """ add_valid_node(
        ARBITRUM_NODE, config["networks"]["arbitrum_sepolia"].get("BC_identifier"), True
    )
    add_valid_node(
        OPTIMISTIC_NODE,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        False,
    ) """  # call on sepolia

    # deposit_node(1 * 10**6, get_account(account="main"))  # call on arbitrum
    """ withdraw(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        0.5 * 10**18,
        get_account(account="main"),
    ) """

    """ warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
        get_account(account="main"),
    ) """  # call on sepolia
    """ warp_assets(
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        get_account(account="main"),
    ) """

    """ warp_assets_arbitrum(
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
    ) """

    # send_node_data_to_master(get_account(account="main"))  # call on nodes
    # get_nodes_data()  # call on sepolia
    # check_ready_for_warp(ARBITRUM_NODE, OPTIMISTIC_NODE)
    # check_var()
    # aWrp_total_supply_node()  # call on Nodes
    # aWrp_total_supply_master()  # call on sepolia
    # aWRP_balance(get_account(account="main"))  # call on Sepolia
    # test_usdc_allowance()
    # balance_usdc(Node[-1])
    # balance_ausdc(Node[-1])
    # balance_link(MasterNode[-1])

    # weth_tester_deposit(0.01 * 10**18, get_account(account="main"))
    # transfer_weth(0.01 * 10**18, ARBITRUM_NODE, get_account(account="main"))
    # weth_tester_withdraw(get_account(account="main"))
    # weth_balance(Node[-1])
    # tester_transfer_eth(0.01 * 10**18)
    # get_link_fee(Node[-1], config["networks"]["sepolia"].get("BC_identifier"))

    ################# UNISWAP V3 ###########################
    # get_pool_uni()
    # get_uni_price()
    # print(get_gas_price())

    print()
    print()
    print("------------------------END SCRIPT-------------------------------")