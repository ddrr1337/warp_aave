from brownie import (
    Master,
    Slave,
    Tester,
    config,
    network,
    interface,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from eth_abi import encode


MASTER_CONTRACT_SEPOLIA = "0x862724af2a6Da4E6549b41A98c178C2B84E6a8a9"
ARBITRUM_NODE = "0x1968958858154F728Fa02b8c9dF1DdD96cd3E8E0"
OPTIMISTIC_NODE = "0xd0780d53707825ff66dACB744a65eF423eB766bE"
BASE_NODE = "0x9d6C9c17FD4B90A03A757A0bBe37F85128DeA5a4"


def deploy_master():
    deploy = Master.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("BC_identifier"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token"),
    )
    transfer = link_contract.transfer(
        Master[-1].address,
        0.5 * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print("Sent 0.5Link to Sender contract")



def deploy_slave(master_contract_address):
    deploy = Slave.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("ausdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        config["networks"][network.show_active()].get("circle_message_transmitter"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        config["networks"][network.show_active()].get("aave_data_provider"),
        master_contract_address,
        config["networks"]["sepolia"].get("BC_identifier"),
        config["networks"][network.show_active()].get("BC_identifier"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )

    """ link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    transfer = link_contract.transfer(
        Slave[-1].address,
        0.5 * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print("Sent 0.5Link to Sender contract")
 """
    if network.show_active() == "arbitrum_sepolia":
        activate_node = deploy.testingActivateNode()
        print("Arbitrum Node Active For Deposits")


def send_message(instance, chainId, destination, message):
    contract = instance
    message_tx = contract.sendMessage(
        chainId,
        destination,
        message,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def read_message(instance, messageIndex):
    contract = instance
    messageId = contract.messagesIds(messageIndex)
    message = contract.message(messageId)
    print(message)


def approve_circle_usdc_on_slave(amount, account):
    approve_erc20(
        Slave[-1],
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def approve_deposit_usdc_on_slave(amount, account):

    approve_circle_usdc_on_slave(amount, account)

    contract = Slave[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def read_balance_master(account):
    contract = Master[-1]
    amount = contract.userBalance(account)
    print(f"Balance of {account}: {amount/10**6} CIRCLE USDC")


def add_valid_node(address, chainCCIPid, isActiveNode):
    contract = Master[-1]
    add_node = contract.addValidNode(
        address,
        chainCCIPid,
        isActiveNode,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def send_to_burn(target_chain_id):
    contract = interface.ITokenMessenger(
        config["networks"][network.show_active()].get("circle_token_messenger")
    )
    burn = contract.depositForBurn(
        0.001 * 10**6,
        target_chain_id,
        get_account(account="main").address,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def test_deploy():
    deploy = Tester.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def warp_assets(
    ccip_chain_id_active_node,
    address_of_active_node,
    circleChainId_new_node,
    ccip_chain_id_new_node,
    address_of_new_node,
):
    contract = Master[-1]
    message_tx = contract.warpAssets(
        ccip_chain_id_active_node,
        address_of_active_node,
        circleChainId_new_node,
        ccip_chain_id_new_node,
        address_of_new_node,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )

    print("Tx confirmed:", message_tx)


def test_allowance():
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allowance = contract.allowance(
        ARBITRUM_NODE,
        config["networks"][network.show_active()].get("circle_token_messenger"),
    )
    print(allowance)


def allowance_link(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    allowance = contract.allowance(
        account,
        ARBITRUM_NODE,
    )
    print("allowed to spend Link", allowance, allowance / 10**18)


def read_warps(messageIndex):
    contract = Slave[-1]
    warp_id = contract.warpIds(messageIndex)
    warp_destination = contract.warpIdToDestinationChain(warp_id)
    print(warp_destination)


def approve_circle_usdc_on_slave(amount, account):
    approve_erc20(
        Slave[-1].address,
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def get_link_fee(instance, destinationCCIPid):
    contract = instance
    uint8_command = 0  # command for deposit
    dummy_mainNonceDeposits = 4  # abritrary number
    dummy_shares = 150 * 10**18  # arbitrary number
    dummy_shares2 = 147 * 10**18  # arbitrary number

    dummy_bytes = encode(
        ["uint8", "address", "uint128", "uint256"],
        [
            uint8_command,
            get_account(account="main").address,
            dummy_mainNonceDeposits,
            dummy_shares,
        ],
    )

    get_fee = contract.getLinkFees(
        destinationCCIPid, get_account(account="main").address, dummy_bytes
    )
    print(get_fee / 10**18)
    return get_fee


def deposit_slave(instance, destinationCCIP, amount, account):
    link_fee = get_link_fee(instance, destinationCCIP) * 1.2
    approve_link_to_slave(link_fee, account)
    approve_circle_usdc_on_slave(amount, account)
    contract = Slave[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def approve_to_burn():
    approve_erc20(
        config["networks"][network.show_active()].get("circle_token_messenger"),
        0.001 * 10**6,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        get_account(account="main"),
    )


def approve_link_to_slave(amount, account):
    approve_erc20(
        Slave[-1].address,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def withdraw_master(chainId, target_address_for_command, amount, account):
    contract = Master[-1]
    withdraw = contract.withdraw(
        chainId,
        target_address_for_command,
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def get_ausdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("ausdc_circle_token")
    )
    balance = contract.balanceOf(account)

    print("AUSDC in Slave", balance)


def get_terster_command():
    contract = Slave[-1]
    command = contract.command()
    print(command)


def get_usdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)

    print("USDC balance: ", balance / 10**6)


def get_link_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    balance = contract.balanceOf(account)

    print("Link balance", balance / 10**18)


def get_test_variables():
    contract = Slave[-1]
    aWrpTotalSupplySlaveView = contract.aWrpTotalSupplySlaveView()
    print(aWrpTotalSupplySlaveView / 10**18)


def testing_return_funds():
    contract = Slave[-1]
    return_funds = contract.testingReturnFunds(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def aWRP_balance(account):
    contract = Master[-1]
    balance = contract.balanceOf(account)

    print(f"aWRP Balance of address: {account.address}")
    print(f"{balance} aWarp Wei")
    print(f"{balance/10**18} aWarp ETH")


def tester_get_deposit_nonces_array(account):
    contract = Slave[-1]
    deposit_array = contract.getUserNonces(account)
    print(deposit_array)
    print(type(deposit_array))


def tester_get_nonce_data_slave(nonce):
    contract = Slave[-1]
    response = contract.nonceDataDeposits(nonce)
    print(response)


def get_aWRP_totalSupply_slave():
    contract = Slave[-1]
    totalSupply = contract.aWrpTotalSupplySlaveView()
    print("aWRP totalSupply Slave side: ", totalSupply, totalSupply / 10**18)


def get_aWRP_totalSupply_master():
    contract = Master[-1]
    totalSupply = contract.totalSupply()
    print("aWRP totalSupply Master side: ", totalSupply, totalSupply / 10**18)


def master_nonce_withdraw(nonce):
    contract = Master[-1]
    address = contract.userNoncesDeposits(nonce)
    print(address)


def deposit_by_nonce(nonce, account):
    contract = Slave[-1]
    deposit = contract.sendDepositByNonce(
        nonce, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def get_pool():
    provider = interface.IPoolAddressesProvider(
        config["networks"][network.show_active()].get("aave_pool_addresses_provider")
    )
    pool = provider.getPool()
    print(pool)


def get_reserves_data():
    contract = interface.IPoolDataProvider(
        config["networks"][network.show_active()].get("aave_data_provider")
    )
    data = contract.getReserveData(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    print(data[5] / 10**27 * 100)


def testerSupplyNonce(address):
    contract = Slave[-1]
    send = contract.testerSendSupplyAndNonce(
        address,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def deploy_sepolia_arbitrum_optimistic_base():
    sepolia_master_contract = ""
    deploy_master()
    sepolia_master_contract = Master[-1].address
    print("------------------------------------------------------------")
    print(f"Deployed Master on {network.show_active()} at {Master[-1].address}")
    print("------------------------------------------------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    deploy_slave(sepolia_master_contract)
    print("------------------------------------------------------------")
    print(f"Deployed Node on {network.show_active()} at {Slave[-1].address}")
    print("------------------------------------------------------------")
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_slave(sepolia_master_contract)
    print("------------------------------------------------------------")
    print(f"Deployed Node on {network.show_active()} at {Slave[-1].address}")
    print("------------------------------------------------------------")
    network.disconnect()
    network.connect("base_sepolia")
    deploy_slave(sepolia_master_contract)
    print("------------------------------------------------------------")
    print(f"Deployed Node on {network.show_active()} at {Slave[-1].address}")
    print("------------------------------------------------------------")
    print("----------------------DEPLOYED ALL CONTRACTS-----------------------")


def main():

    # testing_return_funds()
    # deploy_master()
    # deploy_slave()

    # deploy_sepolia_arbitrum_optimistic_base()
    """add_valid_node(
        ARBITRUM_NODE, config["networks"]["arbitrum_sepolia"].get("BC_identifier"), True
    )
    add_valid_node(
        OPTIMISTIC_NODE,
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        False,
    )
    add_valid_node(
        BASE_NODE,
        config["networks"]["base_sepolia"].get("BC_identifier"),
        False,
    )"""
    """ deposit_slave(
        Slave[-1],
        config["networks"]["sepolia"].get("BC_identifier"),
        1 * 10**6,
        get_account(account="main"),
    ) """
    # deposit_by_nonce(0, get_account(account="main"))
    # get_ausdc_balance(Slave[-1].address)
    # aWRP_balance(get_account(account="main"))
    # aWRP_balance(get_account(account="sec"))
    # aWRP_balance(get_account(account="third"))
    # get_aWRP_totalSupply_slave()
    # get_aWRP_totalSupply_master()
    # get_usdc_balance(get_account(account="main"))
    # get_link_balance(Master[-1].address)
    """withdraw_master(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        1 * 10**18,
        get_account(account="sec"),
    )"""
    """ warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        config["networks"]["optimistic_sepolia"].get("circle_chain_id"),
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
    ) """
    # get_link_fee(Slave[-1], config["networks"]["sepolia"].get("BC_identifier"))

    # tester_get_deposit_nonces_array(get_account(account="main"))
    # master_nonce_withdraw(2)
    # tester_get_nonce_data_slave(3)
    # get_terster_command()
    # get_test_variables()

    # approve_deposit_usdc_on_slave(0.1 * 10**6, get_account(account="main"))

    # approve_to_burn()
    # allowance_link(get_account(account="main"))
    # send_to_burn(7)

    # test_balance()

    # get_reserves_data()

    print("-------------------------------------------------------")
    # print("sepolia_ccip", Slave[-2].address)
    # print("arbitrum_ccip", Slave[-1].address)
    print("-------------------------------------------------------")
