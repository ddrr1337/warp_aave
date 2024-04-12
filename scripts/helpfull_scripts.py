from brownie import accounts, network, config
from brownie import interface, config, network
from web3 import Web3
from brownie import web3


ACCOUNT = "main"

LOCAL_BLOCKCHAIN_ENVIROMENTS = [
    "development",
    "ganache",
    "hardhat",
    "local-ganache",
    "mainnet-fork",
    "mainnet-fork-dev",
]


def get_gas_price():
    gas_price = web3.eth.gas_price

    return gas_price


def get_account(index=None, id=None, account="main"):
    if index:
        print(f"Using account: {accounts[index]}")
        print(accounts[index].balance())
        return accounts[index]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIROMENTS:
        print(f"Using account: {accounts[0]}")
        print(accounts[0].balance())
        return accounts[0]
    if id:
        print(f"Using account: {accounts.load(id)}")
        return accounts.load(id)
    print(f'Using account: {accounts.add(config["wallets"][account]["from_key"])}')
    print(
        f'Account Balance: {accounts.add(config["wallets"][account]["from_key"]).balance()} Wei'
    )
    print("-----------------------------------------------------------------")

    return accounts.add(config["wallets"][account]["from_key"])


def approve_erc20(spender, amount, erc20_address, account):
    erc20 = interface.IERC20(erc20_address)

    tx = erc20.approve(
        spender,
        amount,
        {
            "from": account,
            "gas_price": get_gas_price() * 1.5,
        },
    )
    tx.wait(1)
    allowance = erc20.allowance(account, spender)
    print(f"DAI address: {erc20.address}")
    print(f"Contract spender: {spender}")

    print(f"Approved {allowance} of ERC20 to this spender: {spender}")
    return tx


def get_weth(amount):
    account = get_account()
    weth = interface.IWeth(config["networks"][network.show_active()]["weth_token"])
    tx = weth.deposit({"from": account, "value": amount})
    tx.wait(1)
    print(f"Recived {Web3.fromWei(amount,'ether')} WETH ")
    return tx
