import requests


def get_eth_price():
    url = "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"

    try:
        response = requests.get(url)
        response.raise_for_status()  # Check if the request was successful
        data = response.json()
        usd_price = data.get("USD")

        if usd_price:
            return usd_price
        else:
            raise ValueError("USD price not found in the response.")
    except requests.RequestException as e:
        print(f"Request failed: {e}")
    except ValueError as ve:
        print(f"Value error: {ve}")
