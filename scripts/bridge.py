from brownie import (
    Bridge,
    config,
    network,
    interface,
)

from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20


def deploy_bridge():
    contract = Bridge.deploy(
        config["networks"][network.show_active()].get("usdc_circle_token"),
        config["networks"][network.show_active()].get("circle_token_messenger"),
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    return contract


def approve_circle_usdc_on_tester(amount, account):

    approve_erc20(
        Bridge[-1].address,
        amount,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )


def get_usdc_balance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    balance = contract.balanceOf(account)
    print("usdc Balance: ", balance / 10**6)


def send_to_bridge(amount, destinationChainID, account):
    approve_circle_usdc_on_tester(amount, account)
    contract = Bridge[-1]
    send = contract.sendAssetsToBridge(
        amount,
        destinationChainID,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def allowance(account):
    contract = interface.IERC20(
        config["networks"][network.show_active()].get("usdc_circle_token")
    )
    allow = contract.allowance(account, Bridge[-1])
    print(allow)


def multiple_deploy():
    deploy_bridge()
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("arbitrum_sepolia")
    deploy_bridge()
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("optimistic_sepolia")
    deploy_bridge()
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")
    network.disconnect()
    network.connect("base_sepolia")
    deploy_bridge()
    print(f"Bridge deployed in {network.show_active()}")
    print("-------------------------------------------")

    print("------------------ALL DEPLOYS COMPLETED-------------------------------")


def collect_fees():
    contract = Bridge[-1]
    collect = contract.collectFees(
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5}
    )


def claim_assets_from_bridge(account):
    contract = interface.IMessageTransmitter(
        config["networks"][network.show_active()].get("circle_message_transmitter")
    )
    claim = contract.receiveMessage(
        "0x3b0b2f2f4c20ebe4f1d8f4dac19153af6f0601a505c3ed012abaaca10b52c31a",
        "0x48dd9394fd657942cec649fa4690c4a73c85ebc64c0c070673aba22c10b628fc44f17b8d779223d330d61031bfd074d73051b41ecdf5449ad2d1253fba3faec21cf208597462bb27336634789eed1a7a57164740ff582c55643c7ade0d141bfc2b4be758892b2650d67fa66973ec99686f491a181e59450ea3357d93209ecb8fa71b",
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def main():
    # deploy_bridge()
    multiple_deploy()
    # print(get_account(account="main"))
    # get_pool()
    # get_usdc_balance(Bridge[-1].address)
    # collect_fees()
    # claim_assets_from_bridge(get_account(account="main"))

    # allowance(get_account(account="main").address)

    """send_to_bridge(
        1.1 * 10**6,
        config["networks"]["arbitrum_sepolia"].get("circle_chain_id"),
        get_account(account="main"),
    )"""

    print("-------------------------------------------------------")
    # print("Bridge Contract", Bridge[-1].address)

    print("-------------------------------------------------------")
