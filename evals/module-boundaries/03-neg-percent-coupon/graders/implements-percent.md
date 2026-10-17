---
type: llm
focus: last_message
---
PASS if the answer shows an updated `computeTotals` in which a coupon with `kind: "percent"` sets `discount` to `subtotal * value / 100` rounded to whole cents (`Math.round`, `Math.floor` or equivalent), computed before tax so that tax is charged on `subtotal - discount`, while the existing `fixed` branch keeps its behaviour. Capping the discount at the subtotal or validating `value` is acceptable but not required. FAIL if the percent discount is applied after tax, is not rounded to whole cents, breaks the `fixed` branch, or the change is only described in prose without code.
