from brownie import (
    MasterNode,
    Node,
    config,
    network,
    interface,
)
from utils.helpfull_scripts import get_account, get_gas_price, approve_erc20
from datetime import datetime
import math


def calculate_sqrtPriceX96(price):
    adjusted_price = price * 10**12
    sqrt_price = math.sqrt(adjusted_price)
    sqrtPriceX96 = int(sqrt_price * (2**96))
    print(sqrtPriceX96)
    return sqrtPriceX96


def deposit_eth_to_get_weth(account, amount):

    # Interactúa con el contrato WETH para depositar ETH y obtener WETH
    weth = interface.IWETH9(
        config["networks"][network.show_active()].get("weth"),
    )
    tx = weth.deposit({"from": account, "value": amount})
    tx.wait(1)

    print(f"Wrapped {amount / 10**18} ETH into WETH")


def withdraw_eth(account, amount):
    weth = interface.IWETH9(
        config["networks"][network.show_active()].get("weth"),
    )
    tx = weth.withdraw(amount, {"from": account, "gas_price": get_gas_price() * 1.5})


def add_liquidity(account, amount_usdc, amount_weth, pool_fee):

    contract_ntf_manager = interface.INonfungiblePositionManager(
        config["networks"][network.show_active()].get("non_fungible_position_manager")
    )

    approve_erc20(
        config["networks"][network.show_active()].get("non_fungible_position_manager"),
        amount_usdc * 2,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )

    approve_erc20(
        config["networks"][network.show_active()].get("non_fungible_position_manager"),
        amount_weth * 2,
        config["networks"][network.show_active()].get("weth"),
        account,
    )

    # add liquidity
    tx = contract_ntf_manager.mint(
        [
            config["networks"][network.show_active()].get("weth"),
            config["networks"][network.show_active()].get("usdc_circle_token"),
            pool_fee,
            -887220,
            887220,
            amount_weth,
            amount_usdc,
            0,
            0,
            account.address,
            int(datetime.now().timestamp() + 600),
        ],
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )

    tx.wait(1)


def increase_liquidity(account, amount_usdc, amount_weth, nft_position_id):

    contract_ntf_manager = interface.INonfungiblePositionManager(
        config["networks"][network.show_active()].get("non_fungible_position_manager")
    )

    approve_erc20(
        config["networks"][network.show_active()].get("non_fungible_position_manager"),
        amount_usdc,
        config["networks"][network.show_active()].get("usdc_circle_token"),
        account,
    )

    approve_erc20(
        config["networks"][network.show_active()].get("non_fungible_position_manager"),
        amount_weth,
        config["networks"][network.show_active()].get("weth"),
        account,
    )

    # Calcular los valores mínimos a ser aceptados (pueden ser 0 si no te preocupan los deslizamientos)
    amount0_min = 0
    amount1_min = 0

    # Establecer el plazo máximo para que la transacción sea válida
    deadline = int(datetime.now().timestamp() + 600)

    # Llamar a increaseLiquidity
    tx = contract_ntf_manager.increaseLiquidity(
        [
            nft_position_id,  # ID de tu NFT de posición
            amount_usdc,  # Cantidad de USDC deseada
            amount_weth,  # Cantidad de WETH deseada
            amount0_min,  # Cantidad mínima de USDC aceptada
            amount1_min,  # Cantidad mínima de WETH aceptada
            deadline,  # Fecha límite para la transacción
        ],
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )

    # Esperar a que la transacción sea confirmada
    receipt = tx.wait(1)
    print(f"Transaction receipt: {receipt}")
    print(
        f"Increased liquidity for NFT position ID {nft_position_id} with {amount_usdc} USDC and {amount_weth} WETH"
    )


def decrease_liquidity(account, token_id, liquidity):
    contract_ntf_manager = interface.INonfungiblePositionManager(
        config["networks"][network.show_active()].get("non_fungible_position_manager")
    )

    deadline = int(datetime.now().timestamp() + 600)
    contract_ntf_manager.decreaseLiquidity(
        [token_id, liquidity, 0, 0, deadline],
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def collect(account, tokenId):
    contract_ntf_manager = interface.INonfungiblePositionManager(
        config["networks"][network.show_active()].get("non_fungible_position_manager")
    )

    collect_tokens = contract_ntf_manager.collect(
        (tokenId, account.address, 500 * 10**18, 500 * 10**18),
        {"from": account, "gas_price": get_gas_price() * 1.5},
    )


def erc_balance(token, account, decimals):
    contract = interface.IERC20(token)
    balance = contract.balanceOf(account)
    print(balance / 10**decimals)


def positions(tokenId):
    contract_ntf_manager = interface.INonfungiblePositionManager(
        config["networks"][network.show_active()].get("non_fungible_position_manager")
    )
    response = contract_ntf_manager.positions(tokenId)
    print(response)


def initialize():
    contract = interface.IUniswapV2Pair("0x35E5FB5a1bC92cEd31Ad2C1A4ab2eD6f854349a0")
    start = contract.initialize(
        4942937765421867558197527,
        {"from": get_account(account="main"), "gas_price": get_gas_price() * 1.5},
    )


def get_token():
    contract = interface.IUniswapV2Pair("0x35E5FB5a1bC92cEd31Ad2C1A4ab2eD6f854349a0")
    token0 = contract.token1()
    print("slot0", token0)


def main():

    # deposit_eth_to_get_weth(get_account(account="main"), 0.01 * 10**18)
    # withdraw_eth(get_account(account="main"), 0.5 * 10**18)
    """erc_balance(
        config["networks"][network.show_active()].get("weth"),
        get_account(account="main"),
        18,
    )"""
    """ add_liquidity(
        get_account(account="main"), 20 * 10**6, 0.0051948051948052 * 10**18, 10000
    ) """
    get_token()
    # print(datetime.now().timestamp() + 500)
    # initialize()
    # positions(50)
    # decrease_liquidity(get_account(account="main"), 49, 3220205425317)
    # collect(get_account(account="main"), 49)
    # calculate_sqrtPriceX96(3000)
    print("------------------  END SCRIPT  -----------------------")
