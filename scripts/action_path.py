from brownie import (
    Master,
    Slave,
    Tester,
    config,
    network,
    interface,
)
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20


SEPOLIA_RECEIVER = "0x5b3759E7ab559b95Ddf686a650fb586466c4d094"
ARBITRUM_RECEIVER = "0xCacC68eC6b22d799585b6cfCB7032F13E1C13632"
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
        1 * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print("Sent 1Link to Sender contract")


def deploy_slave():
    deploy = Slave.deploy(
        config["networks"][network.show_active()].get("router_ccip_address"),
        config["networks"][network.show_active()].get("link_token"),
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        config["networks"][network.show_active()].get("aave_pool_addresses_provider"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    link_contract = interface.IERC20(
        config["networks"][network.show_active()].get("link_token")
    )
    transfer = link_contract.transfer(
        Slave[-1].address,
        1 * 10**18,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    print("Sent 1Link to Sender contract")


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


def test_balance():
    contract = interface.IERC20("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238")

    balance = contract.balanceOf("0x8B69C9396B6A40050E1A5D52025D487F551755CD")
    print("balance test", balance)


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
    contract = interface
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
    contract = Slave[-1]
    deposit = contract.deposit(
        amount,
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def get_ausdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("ausdc_circle_token")
    )
    balance = contract.balanceOf(account)

    print("AUSDC in Slave", balance)


def main():

    # deploy_master()
    # deploy_slave()
    # add_valid_node(ARBITRUM_RECEIVER)
    # approve_circle_usdc_on_slave(1 * 10**6, get_account(account="main"))
    # deposit_slave(1 * 10**6, get_account(account="main"))
    get_ausdc_balance(Slave[-1].address)
    # read_balance_master(get_account(account="main").address)
    """warp_assets(
        config["networks"]["arbitrum_sepolia"].get("BC_identifier"),
        ARBITRUM_RECEIVER,
        config["networks"]["polygon-test"].get("circle_chain_id"),
        "0x26baAC08CB753303de111e904e19BaF91e6b5E4d",
    )"""

    """send_message(
        Slave[-1],
        config["networks"]["sepolia"].get("BC_identifier"),
        SEPOLIA_RECEIVER,
        "message to master sepolia",
    )"""
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
    print("-------------------------------------------------------")
    # print("sepolia_ccip", Master[-1].address)
    # print("arbitrum_ccip", Slave[-1].address)
    print("-------------------------------------------------------")
