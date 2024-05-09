from brownie import LockToken
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20

from datetime import datetime


AAPLE_CONTRACT_ADDRESS = "0x1370317e525AD6660FcAF652Ca82C0453d46dC23"
deadline = int(datetime.now().timestamp() + 3600)


def deploy_tester():
    contract = LockToken.deploy(
        AAPLE_CONTRACT_ADDRESS,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )
    return contract


def approve_APPLE(account):
    approve_erc20(
        LockToken[-1],
        0.1 * 10**18,
        AAPLE_CONTRACT_ADDRESS,
        account,
    )


def deposit_AAPLE(account):
    contract = LockToken[-1]
    deposit = contract.deposit(
        0.1 * 10**18, deadline, {"from": account, "gas_price": get_gas_price() * 1.5}
    )
    return deposit


def main():
    # deploy_tester()
    # approve_APPLE(get_account(account="main"))
    # deposit_AAPLE(get_account(account="main"))
    # print(deadline)
    print(datetime.now().timestamp())
    print("-------------------------------------------------------")
