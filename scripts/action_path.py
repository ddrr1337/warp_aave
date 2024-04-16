from brownie import (
    Master,
    Slave,
    Tester,
    config,
    network,
    interface,
)
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20


MASTER_CONTRACT_SEPOLIA = "0x084216A0AD8d54F35B060AEF35863B0EeBD32e9e"
ARBITRUM_RECEIVER = "0x2539105f928df258EE5C883d549e82ebBF149D1E"

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
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
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


def claim_assets(message_bytes, attestation_hash):
    contract = interface.IMessageTransmitter(
        config["networks"][network.show_active()].get("circle_message_transmitter")
    )
    claim = contract.receiveMessage(
        message_bytes,
        attestation_hash,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def test_deploy():
    deploy = Tester.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def warp_assets(chainId, target_address_for_command, circleChainId, mintReciepent):
    contract = Master[-1]
    message_tx = contract.warpAssets(
        chainId,
        target_address_for_command,
        circleChainId,
        mintReciepent,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )

    print("Tx confirmed:", message_tx)


def test_allowance():
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allowance = contract.allowance(
        ARBITRUM_RECEIVER,
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


def get_Configuration(poolAddress):
    contract = interface.IPool(poolAddress)
    configuration = contract.getReserveNormalizedIncome(
        config["networks"][network.show_active()].get("ausdc_circle_token")
    )
    print(configuration)


def main():

    # testing_return_funds()
    # deploy_master()
    # deploy_slave()
    # add_valid_node(ARBITRUM_RECEIVER)
    # deposit_slave(5 * 10**6, get_account(account="sec"))
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
        ARBITRUM_RECEIVER,
        4999995000004999995,
        get_account(account="sec"),
    )"""
    """ warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_RECEIVER,
        config["networks"]["polygon-test"].get("circle_chain_id"),
        "0x26baAC08CB753303de111e904e19BaF91e6b5E4d",
    ) """
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

    # test_deploy()
    # test_balance()
    # claim_assets(data_bytes(), get_attestation())

    get_Configuration("0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff")
    print("-------------------------------------------------------")
    # print("sepolia_ccip", Master[-1].address)
    # print("arbitrum_ccip", Slave[-1].address)
    print("-------------------------------------------------------")
