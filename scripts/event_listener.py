from brownie import Contract, network, config, interface
from scripts.helpfull_scripts import get_account, get_gas_price, approve_erc20
from .tx_handler import TxHandler
from web3 import Web3
from hexbytes import HexBytes

# Asegúrate de establecer la red correctamente en tu script


# Dirección del contrato y nombre del evento

tx_usdc = "0x3aeeaadddc69489029703d10109af6dcde68b2a5671d9328f2dc43ce8a70d6d9"
# tx_usdc = "0xe2900d950335010a5e8c29ac630c7997a6a415e51567c5e5aece3619d0bff682"
# Reemplaza con el nombre del evento que deseas escuchar


# Carga el contrato
contract = interface.IERC20(
    config["networks"][network.show_active()].get("usdc_circle_token")
)
balance = contract.balanceOf(get_account(account="main"))


def data_bytes():
    tx = TxHandler(tx_usdc, config["networks"][network.show_active()].get("host"))
    return "0x" + tx.retrieve_data_bytes()[0].hex()


def get_attestation():
    tx = TxHandler(tx_usdc, config["networks"][network.show_active()].get("host"))

    attestation = tx.get_attestation_from_circle()

    return attestation["attestation"]


def callBack(event):
    print("Tx: ", event.transactionHash.hex())
    print("---------------------------------------------------------")

    tx_read = event.transactionHash.hex()
    tx = TxHandler(tx_read, config["networks"][network.show_active()].get("host"))
    tx_recipent = tx.get_transaction_receipt()

    for log in tx_recipent["logs"]:
        if (
            log["topics"][0].hex()
            == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        ):

            address_hex = "0x" + log["topics"][1].hex()[-40:]

            if address_hex == "0x127B4Ba64A2F6523B9892ecABe8bA0832fd7b76b".lower():
                print(
                    "-------------------------messageBytes-------------------------------------"
                )
                print(data_bytes())
                print(
                    "-------------------------attestation-------------------------------------"
                )
                print(get_attestation())


contract.events.subscribe("Transfer", callBack)


def get_attestation():
    tx = TxHandler(tx_usdc, config["networks"][network.show_active()].get("host"))

    attestation = tx.get_attestation_from_circle()

    return attestation["attestation"]


def main():

    while True:
        pass

    print("-------------------------messageBytes-------------------------------------")
    # print(data_bytes())
    print("-------------------------attestation-------------------------------------")
    # print(get_attestation())

    print(
        "--------------------------------------txData----------------------------------"
    )
