---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that the cart stores derived values (`subtotalCents`, `discountCents`, `taxCents`, `totalCents`, and the effect of `freeShipping` on `shippingCents`) as fields that are only correct if the right `recalc*` methods were called in the right order after each change, and backs this with at least two concrete consequences from the code, such as: `removeItem` does not recompute the subtotal and the drawer only calls `recalcTotal`, so the shown total is stale; a percent coupon's `discountCents` is computed once from the subtotal at apply time and never updated when items change; a free-shipping coupon only takes effect if applied before `setShipping`; `onPlaceOrder` has to defensively recompute everything. AND frames the root cause in complexity terms: hidden dependencies / implicit ordering obligations that nothing in the interface reveals (unknown unknowns, obscurity, high cognitive load, or equivalent), which is why each patch fixes one path and another breaks, AND recommends removing the obligation rather than adding more recalc calls: store only the inputs (lines, coupon, shipping quote) and compute the totals from them on read in one place (e.g. a `totals()` method or getters), with the derived fields no longer publicly assignable.

FAIL if the answer only lists individual bugs fixed by inserting more `recalcSubtotal()` / `recalcTotal()` calls, or never connects the tickets to the stored-derived-state / ordering obligation.
