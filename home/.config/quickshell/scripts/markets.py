#!/usr/bin/env python3

# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   M A R K E T S                                                          │
# │   prices for a watchlist · coingecko and the ecb's rates                 │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Prices, the day's change and a recent history for a list of pairs.

Each argument is a pair, BASE/QUOTE, or a base alone, quoted in US dollars.
A base the ECB publishes a rate for (EUR/USD, GBP/JPY) is a currency, read
from Frankfurter: daily reference rates, a month of them, the change since
the previous working day. Anything else is a coin, read from CoinGecko by its
symbol: the price now, the change over 24 hours and a week of hourly prices.
Neither needs a key.

A pair neither source knows is listed under `unknown`, so the settings can
say so. A failed request reports nothing for its pairs, and the shell keeps
its last good reading.
"""

import json
import subprocess
import sys
from datetime import date, timedelta
from urllib.parse import urlencode

COINS = "https://api.coingecko.com/api/v3/coins/markets"
RATES = "https://api.frankfurter.dev/v1"
TIMEOUT = 12

# The currencies the ECB publishes reference rates for.
FIAT = {
    "AUD", "BGN", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP",
    "HKD", "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR",
    "NOK", "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD",
    "ZAR",
}

# Points kept from CoinGecko's 168 hourly prices: one every three hours.
STRIDE = 3


def fetch(url):
    result = subprocess.run(
        ["curl", "-sS", "--fail", "--max-time", str(TIMEOUT), url],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"no answer from {url}")
    return json.loads(result.stdout)


def parse(text):
    """BTC/EUR is ("BTC", "EUR"); BTC alone is ("BTC", "USD")."""
    base, _, quote = text.strip().upper().partition("/")
    return base.strip(), (quote.strip() or "USD")


def coins(pairs):
    """Every coin pair with one quote, in one request."""
    quote = pairs[0][1]
    query = urlencode({
        "vs_currency": quote.lower(),
        "symbols": ",".join(base.lower() for base, _ in pairs),
        "sparkline": "true",
        "price_change_percentage": "24h",
    })
    found = {}
    for coin in fetch(f"{COINS}?{query}"):
        series = (coin.get("sparkline_in_7d") or {}).get("price") or []
        price = coin.get("current_price")
        if price is None:
            continue
        found[coin["symbol"].upper()] = {
            "kind": "coin",
            "name": coin.get("name") or coin["symbol"].upper(),
            "price": price,
            "change": coin.get("price_change_percentage_24h") or 0,
            "series": series[::STRIDE] + series[-1:],
            "span": "7 d",
            "period": "24 h",
        }
    return found


def rate(base, quote):
    start = (date.today() - timedelta(days=45)).isoformat()
    query = urlencode({"from": base, "to": quote})
    answer = fetch(f"{RATES}/{start}..?{query}")
    days = sorted(answer.get("rates", {}).items())
    series = [values[quote] for _, values in days if quote in values]
    if len(series) < 2:
        return None
    return {
        "kind": "currency",
        "name": f"{base} → {quote}",
        "price": series[-1],
        "change": (series[-1] / series[-2] - 1) * 100,
        "series": series[-30:],
        "span": "30 d",
        "period": "1 d",
    }


def report(arguments):
    pairs = []
    for text in arguments:
        base, quote = parse(text)
        if base and (base, quote) not in pairs:
            pairs.append((base, quote))

    readings = {}
    unknown = []
    failed = False

    # Coins grouped by the currency they are quoted in.
    quotes = {}
    for base, quote in pairs:
        if base not in FIAT:
            quotes.setdefault(quote, []).append((base, quote))
    for quote, group in quotes.items():
        try:
            found = coins(group)
        except Exception as error:
            sys.stderr.write(f"markets: coingecko failed: {error}\n")
            failed = True
            continue
        for base, _ in group:
            if base in found:
                readings[(base, quote)] = found[base]
            else:
                unknown.append(f"{base}/{quote}")

    for base, quote in pairs:
        if base not in FIAT:
            continue
        if quote not in FIAT or quote == base:
            unknown.append(f"{base}/{quote}")
            continue
        try:
            reading = rate(base, quote)
        except Exception as error:
            sys.stderr.write(f"markets: frankfurter failed: {error}\n")
            failed = True
            continue
        if reading is None:
            unknown.append(f"{base}/{quote}")
        else:
            readings[(base, quote)] = reading

    items = []
    for base, quote in pairs:
        if (base, quote) in readings:
            items.append({"base": base, "quote": quote, **readings[(base, quote)]})

    return {
        "available": bool(items),
        "complete": not failed,
        "items": items,
        "unknown": unknown,
    }


if __name__ == "__main__":
    arguments = [text for text in sys.argv[1:] if text.strip()]
    if not arguments:
        print(json.dumps({"available": False, "complete": True, "items": [], "unknown": []}))
        sys.exit(0)
    try:
        print(json.dumps(report(arguments)))
    except Exception as error:  # a widget must never take the shell down
        sys.stderr.write(f"markets failed: {error}\n")
        print(json.dumps({"available": False, "complete": False, "items": [], "unknown": []}))
