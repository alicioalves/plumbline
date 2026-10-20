---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
This is `billing/plans.py`. It's harder to work with than it should be. Every change to pricing seems to take longer than anyone estimates, and people keep getting surprised by it, but I can't put my finger on why. What's going on with it?

```python
# billing/plans.py
from decimal import Decimal, ROUND_HALF_UP

from billing import fx
from billing.models import Account, Invoice, LineItem

PLAN_IDS = ["free", "starter", "team", "business", "enterprise"]
MONTHLY_CENTS = [0, 900, 2900, 7900, None]
SEAT_LIMITS = [1, 3, 25, 100, None]
ANNUAL_DISCOUNT_PCT = [0, 10, 15, 15, 0]

INCLUDED_SEATS = 5
EXTRA_SEAT_CENTS = 500
PLATFORM_FEE_CENTS = 200

_fx_rates = {}


def _plan_index(plan_id):
    return PLAN_IDS.index(plan_id)


def monthly_price_cents(account: Account) -> int:
    if account.plan_id == "enterprise":
        return account.contract_cents
    i = _plan_index(account.plan_id)
    cents = MONTHLY_CENTS[i]
    if account.billing_period == "annual":
        cents = cents * (100 - ANNUAL_DISCOUNT_PCT[i]) // 100
    return cents


def can_add_seat(account: Account) -> bool:
    limit = SEAT_LIMITS[_plan_index(account.plan_id)]
    if limit is None:
        return True
    return account.seat_count < limit


def is_upgrade(old_plan: str, new_plan: str) -> bool:
    return _plan_index(new_plan) > _plan_index(old_plan)


def invoice_total(account: Account) -> Invoice:
    global _fx_rates
    _fx_rates = fx.fetch_rates(base="USD")

    lines = [LineItem("Subscription", monthly_price_cents(account))]
    if account.plan_id in ("team", "business") and account.seat_count > INCLUDED_SEATS:
        extra = account.seat_count - INCLUDED_SEATS
        lines.append(LineItem(f"Extra seats x{extra}", extra * EXTRA_SEAT_CENTS))
    if account.plan_id not in ("free", "enterprise"):
        lines.append(LineItem("Platform fee", PLATFORM_FEE_CENTS))

    usd_cents = sum(line.cents for line in lines)
    rate = Decimal(str(_fx_rates[account.currency]))
    total = (Decimal(usd_cents) * rate).quantize(Decimal("1"), ROUND_HALF_UP)
    return Invoice(
        account_id=account.id,
        lines=lines,
        total_cents=int(total),
        currency=account.currency,
    )


def display_price(account: Account) -> str:
    cents = monthly_price_cents(account)
    rate = Decimal(str(_fx_rates.get(account.currency, 1)))
    amount = Decimal(cents) * rate / 100
    return f"{amount:.2f} {account.currency}"


def plan_badge(plan_id: str) -> str:
    if plan_id == "enterprise":
        return "Enterprise"
    if plan_id in ("team", "business"):
        return "Pro"
    return plan_id.title()


def trial_days(plan_id: str) -> int:
    if plan_id in ("team", "business"):
        return 14
    return 0
```

`display_price` is used by the pricing page and the account settings page; `invoice_total` runs from the nightly billing job and from the "preview invoice" button.
