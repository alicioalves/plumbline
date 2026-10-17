---
type: llm
focus: last_message
---
PASS if the answer identifies that what a plan *is* is spread across many places — the position-aligned parallel lists (`PLAN_IDS`, `MONTHLY_CENTS`, `SEAT_LIMITS`, `ANNUAL_DISCOUNT_PCT`, where the list order also silently defines `is_upgrade`) plus hard-coded plan-name checks in at least one of `monthly_price_cents`, `invoice_total`, `plan_badge`, `trial_days` — AND states the consequence in design terms: adding, removing, reordering or changing a plan requires coordinated edits in many places that nothing enforces (change amplification, scattered knowledge, or equivalent), AND recommends consolidating each plan's properties into one definition (e.g. a `Plan` record/dataclass/table keyed by id that carries price, seat limit, discount, badge, trial, fee rules, rank).

FAIL if this is not raised, if only one list or one if-chain is mentioned without the multi-place-edit consequence, or if it is treated only as style (e.g. "use an Enum", "magic strings") with no point about how many places a single plan change touches.
