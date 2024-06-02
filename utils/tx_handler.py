""" NOT NEEDED ANYMORE ONLY USED TO TEST BRIDGE """

from web3 import Web3
from eth_abi import abi
import requests
from web3.middleware import geth_poa_middleware


class TxHandler:

    def __init__(self, tx_hash=None, provider_url=None):
        self.tx_hash = tx_hash
        self.cirle_api_endpoint = "https://iris-api-sandbox.circle.com/v1/attestations/"
        if provider_url:
            self.web3 = Web3(Web3.WebsocketProvider(provider_url))

    def get_transaction_receipt(self):
        """
        Retrieves the transaction receipt for the specified transaction hash.
        """
        return self.web3.eth.get_transaction_receipt(self.tx_hash)

    def retrieve_data_bytes(self):

        transaction_receipt = self.get_transaction_receipt()
        if transaction_receipt is None:
            return []

        event_topic = Web3.keccak(text="MessageSent(bytes)").hex()

        log = next(
            (
                l
                for l in transaction_receipt["logs"]
                if l["topics"][0].hex() == event_topic
            ),
            None,
        )

        message_bytes = abi.decode(["bytes"], log["data"])

        return message_bytes

    def message_hash(self):
        """
        Calculates the keccak hash of the message bytes.
        """
        message_bytes = self.retrieve_data_bytes()
        if not message_bytes:
            print("No message bytes found.")
            return

        message_hash = Web3.keccak(message_bytes[0]).hex()

        return message_hash

    def get_attestation_from_circle(self):

        try:
            message_hash = self.message_hash()

            url = f"{self.cirle_api_endpoint}{message_hash}"

            response = requests.get(url)

            if response.status_code == 200:
                return response.json()
            else:
                print(
                    "Failed Request code response: ",
                    response.status_code,
                )
                return None

        except Exception as e:
            print("Error processing request:", e)
            return None
