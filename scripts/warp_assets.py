"""THIS IS AN EXAMPLE OF SCRIPT TO ALLOW A WARP FROM ACTIVE NODE TO BASE NODE"""

"""NOT REQUIRED TO SEND AAVE DATA FRON NODES TO MASTER BECAUSE PROTOCOL IN IN TEST MODE"""
"""IF YOU TRY THIS WHEN PROTOCOL IS NOT IN TEST MODE THIS TRANSACTION WILL FAIL"""
"""SET THE ADDRESS OF BASE NODE DEPLOYMENT FIRST"""


from brownie import (
    MasterNode,
    config,
    network,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20

BASE_NODE = (
    "0x37bcc8077B9C320F311A6C395cc4E0Bb616D3065"  # Put here the BASE node deployed
)
ARBITRUM_NODE = ""  # Put here the Arbitrum node deployed
OPTIMISTIC_NODE = ""  # Put here the Optimistic node deployed


def approve_link(spender, amount, account):
    approve_erc20(
        spender,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def warp_assets(destinationNodeAddress, account):

    approve_link(MasterNode[-1], 10 * 10**18, account)

    contract = MasterNode[-1]
    warp_assets = contract.warpAssets(
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def main():
    """CALL THIS FUNCTION ON ACTIVE NODE CHAIN"""
    """CALL ONLY ONE, DO NOT CALL ALL"""

    warp_assets(
        BASE_NODE,  # Set the address of BASE Node deployed
        get_account(account="main"),
    )
    """ warp_assets(
        ARBITRUM_NODE,  # Set the address of Arbitrum Node deployed
        get_account(account="main"),
    ) """
    """ warp_assets(
        OPTIMISTIC_NODE,  # Set the address of Optimistic Node deployed
        get_account(account="main"),
    ) """

    print("--------------------------------------------------------")
