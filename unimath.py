import math

min_tick = -887272
max_tick = 887272

q96 = 2**96
eth = 10**18


def price_to_tick(p):
    return math.floor(math.log(p, 1.0001))


def price_to_sqrtp(p):
    return int(math.sqrt(p) * q96)


def tick_to_sqrtp(t):
    return int((1.0001 ** (t / 2)) * q96)


def liquidity0(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return (amount * (pa * pb) / q96) / (pb - pa)


def liquidity1(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return amount * q96 / (pb - pa)

from decimal import Decimal
def calc_amount0(liq, pa, pb):  # 1517882343751509868544  5604469350942327889444743441197   5602277097478614198912276234240
    if pa > pb: # true
        pa, pb = pb, pa # pa=5602277097478614198912276234240 pb = 5604469350942327889444743441197
        print("Selling", liq * q96) # 120259029008277069663908933879274768668093824630784
        result = Decimal(liq * q96 * (pb - pa) / pb) # 4.704071989293917e+46
        print("result", result) # 47040719892939165959294306852172556914862850048
    return int(liq * q96 * (pb - pa) / pb / pa)
        # 1517882343751509868544 * (5604469350942327889444743441197 - 5602277097478614198912276234240) / 5604469350942327889444743441197 / 5602277097478614198912276234240


def calc_amount1(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * (pb - pa) / q96)


# Liquidity provision
price_low = 4545
price_cur = 5000
price_upp = 5500

print(f"Price range: {price_low}-{price_upp}; current price: {price_cur}")

sqrtp_low = price_to_sqrtp(price_low)
sqrtp_cur = price_to_sqrtp(price_cur)
sqrtp_upp = price_to_sqrtp(price_upp)

amount_eth = 1 * eth
amount_usdc = 5000 * eth

liq0 = liquidity0(amount_eth, sqrtp_cur, sqrtp_upp)
liq1 = liquidity1(amount_usdc, sqrtp_cur, sqrtp_low)
liq = int(min(liq0, liq1))

print(f"Deposit: {amount_eth/eth} ETH, {amount_usdc/eth} USDC; liquidity: {liq}")

# Swap USDC for ETH
amount_in = 42 * eth

print(f"Selling {amount_in/eth} USDC")

price_diff = (amount_in * q96) // liq
price_next = sqrtp_cur + price_diff

print("New price:", (price_next / q96) ** 2)
print("(price_next / q96)", (price_next / q96))
print("New sqrtP:", price_next) #  5604469350942327889444743441197
print("New tick:", price_to_tick((price_next / q96) ** 2))

amount_in = calc_amount1(liq, price_next, sqrtp_cur) # 1517882343751509868544  5604469350942327889444743441197   5602277097478614198912276234240
amount_out = calc_amount0(liq, price_next, sqrtp_cur) # 1517882343751509868544  5604469350942327889444743441197   5602277097478614198912276234240

print("USDC in:", amount_in / eth) # USDC in: 42.0
print("ETH out:", amount_out / eth) # ETH out: 0.008396714242162444
