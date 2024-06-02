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

BASE_NODE = ""  # Put here the BASE node deployed
ARBITRUM_NODE = ""  # Put here the Arbitrum node deployed


def approve_link(spender, amount, account):
    approve_erc20(
        spender,
        amount,
        config["networks"][network.show_active()].get("link_token"),
        account,
    )


def warp_assets(destinationCCIPid, destinationNodeAddress, account):

    approve_link(MasterNode[-1], 10 * 10**18, account)

    contract = MasterNode[-1]
    warp_assets = contract.warpAssets(
        destinationCCIPid,
        destinationNodeAddress,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def main():
    """CALL THIS FUNCTION ON ACTIVE NODE CHAIN"""
    """CALL ONLY ONE, DO NOT CALL BOTH"""

    """ warp_assets(
        config["networks"]["base_sepolia"].get(
            "BC_identifier"
        ),  # setted base_sepolia CCIPid
        BASE_NODE,  # Set the address of BASE Node deployed
        get_account(account="main"),
    ) """
    warp_assets(
        config["networks"]["arbitrum_sepolia"].get(
            "BC_identifier"
        ),  # setted base_sepolia CCIPid
        ARBITRUM_NODE,  # Set the address of BASE Node deployed
        get_account(account="main"),
    )

    print("--------------------------------------------------------")
