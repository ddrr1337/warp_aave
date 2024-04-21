from brownie import (
    Master,
    Slave,
    Tester,
    config,
    network,
    interface,
)
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20


MASTER_CONTRACT_SEPOLIA = "0xBe228f5726bF7c8ad28493D1e48de6b7Efb12fc5"
ARBITRUM_NODE = "0x58Af01A9ab59e12a2CdB95B8AFc85CeEe47c6818"
OPTIMISTIC_NODE = "0xC291786C4Ca1d985FC6f4b5428300263Be529db5"

tx_base = "0x453ae978d12682d8606f75e5536abb1d26b45e50c552f5b416537c590d81df91"


def deploy_master():
    deploy = Master.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
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


def deploy_slave():
    deploy = Slave.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("ausdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        config["networks"][network.show_active()].get("circle_message_transmitter"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        config["networks"][network.show_active()].get("aave_data_provider"),
        MASTER_CONTRACT_SEPOLIA,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    transfer = link_contract.transfer(
        Slave[-1].address,
        0.5 * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print("Sent 0.5Link to Sender contract")

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


def add_valid_node(address):
    contract = Master[-1]
    add_node = contract.addValidNode(
        address,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def add_valid_nodes(nodes):
    for node in nodes:
        add_valid_node(node)


def approve_to_burn():
    approve_erc20(
        config["networks"][network.show_active()].get("circle_token_messenger"),
        0.001 * 10**6,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        get_account(account="main"),
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


def deposit_slave(amount, account):
    approve_circle_usdc_on_slave(amount, account)
    contract = Slave[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
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


def feed_data_from_slave():
    contract = Slave[-1]
    feed = contract.sendAaveData(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def get_node_data(node_address):
    contract = Master[-1]
    data_node = contract.activeNodes(node_address)
    print(data_node)


def testerSuccess():
    contract = Slave[-1]
    success = contract.aWrpTotalSupplySlaveView()
    print(success)


def testerSupplyNonce(address):
    contract = Slave[-1]
    send = contract.testerSendSupplyAndNonce(
        address,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def claim_from_bridge(message, attestation, account):
    contract = Slave[-1]
    claim = contract.claimAssetsFromBridge(
        message, attestation, {"from": account, "gas_price": get_gas_price() * 1.5}
    )


def main():

    # testing_return_funds()
    # deploy_master()
    # deploy_slave()

    # add_valid_nodes([ARBITRUM_NODE, OPTIMISTIC_NODE])

    # deposit_slave(1 * 10**6, get_account(account="main"))
    # deposit_by_nonce(0, get_account(account="main"))
    # get_ausdc_balance(Slave[-1].address)
    # aWRP_balance(get_account(account="main"))
    # aWRP_balance(get_account(account="sec"))
    # aWRP_balance(get_account(account="third"))
    # get_aWRP_totalSupply_slave()
    get_aWRP_totalSupply_master()
    # get_usdc_balance(Slave[-1].address)
    # get_link_balance(Master[-1].address)
    """withdraw_master(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        5000000000000000000,
        get_account(account="third"),
    )"""
    """ warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_NODE,
        config["networks"]["optimistic_sepolia"].get("circle_chain_id"),
        config["networks"]["optimistic_sepolia"].get("BC_identifier"),
        OPTIMISTIC_NODE,
    ) """
    # testerSuccess()
    # testerSupplyNonce("0xAF2650dBc39b6911D4788548CD98FD1d61a653dF")
    # get_node_data(ARBITRUM_NODE)
    # tester_get_deposit_nonces_array(get_account(account="main"))
    # master_nonce_withdraw(2)
    # tester_get_nonce_data_slave(3)
    # get_terster_command()
    # get_test_variables()

    # read_message(Master[-1], 1)
    # read_warps(0)
    # approve(Slave[-1], 10 * 10**6, get_account(account="main"))
    # approve_deposit_usdc_on_slave(0.1 * 10**6, get_account(account="main"))

    # approve_to_burn()
    # test_allowance()
    # send_to_burn(7)

    # test_balance()
    """ claim_from_bridge(
        "0x0000000000000003000000020000000000002e300000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa50000000000000000000000009f3b8679c73c2fef8b59b4f3444d4e156fb70aa500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000075faf114eafb1bdbe2f0316df893fd58ce46aa4d000000000000000000000000c291786c4ca1d985fc6f4b5428300263be529db500000000000000000000000000000000000000000000000000000000001e848100000000000000000000000058af01a9ab59e12a2cdb95b8afc85ceee47c6818",
        "0x602094ff6e9d07822a9418c8518ce2c3b8e62d5d0a8353ae7d85aa37a413609f3c1baf75fcac03d111b3fa93b749afc482a2f52ba01a85f23da6c9526a0b8b3b1ca75733b874ac631e0d88b43f96d65bdd37ccf053636e1d27f40834e15875e3776001ef10ca28952596114d6c0b4628759850c9a9e1e2f4e1283af27a4befc87f1b",
        get_account(account="main"),
    ) """

    # get_reserves_data()
    # feed_data_from_slave()
    print("-------------------------------------------------------")
    # print("sepolia_ccip", Master[-1].address)
    # print("arbitrum_ccip", Slave[-1].address)
    print("-------------------------------------------------------")
