from brownie import Contract, Slave, network, config, interface
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from utils.tx_handler import TxHandler
from web3 import Web3
from hexbytes import HexBytes


final_tx = "0xb5b77960afc2737fec38cac02e4231582d6ce954f9eb06ce89d96e2a0b1a865b"


# Carga el contrato
contract = interface.IERC20(
    config["networks"][network.show_active()].get("usdc_circle_token")
)
balance = contract.balanceOf(get_account(account="main"))


def data_bytes(tx_hash):
    tx = TxHandler(tx_hash, config["networks"][network.show_active()].get("host"))
    return "0x" + tx.retrieve_data_bytes()[0].hex()


def get_attestation(tx_hash):
    tx = TxHandler(tx_hash, config["networks"][network.show_active()].get("host"))

    attestation = tx.get_attestation_from_circle()

    return attestation["attestation"]


def get_data(tx):
    print("-------------------------messageBytes-------------------------------------")
    print(data_bytes(tx))
    print("-------------------------attestation-------------------------------------")
    print(get_attestation(tx))


found = False


def callBack(event):
    global found

    print("Tx: ", event.transactionHash.hex())
    print("---------------------------------------------------------")
    found = True

    tx_read = event.transactionHash.hex()
    tx = TxHandler(tx_read, config["networks"][network.show_active()].get("host"))
    tx_recipent = tx.get_transaction_receipt()

    for log in tx_recipent["logs"]:
        if (
            log["topics"][0].hex()
            == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        ):

            address_hex = "0x" + log["topics"][1].hex()[-40:]

            if address_hex == Slave[-1].address.lower():
                print(
                    "-------------------------messageBytes-------------------------------------"
                )
                print(data_bytes(event.transactionHash.hex()))
                # print(data_bytes(final_tx))
                print(
                    "-------------------------attestation-------------------------------------"
                )
                print(get_attestation(event.transactionHash.hex()))
                # print(get_attestation(final_tx))


contract.events.subscribe("Transfer", callBack)


def main():
    """print("-----------------------LISTENING EVENTS-----------------------------------")
    while not found:

        pass"""

    get_data("0x0354eaea4811bbc63699558226fa55b7d6caa212c0047cba0bced7e6f12c335e")
