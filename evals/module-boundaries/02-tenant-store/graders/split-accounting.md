---
type: llm
focus: last_message
---
PASS if the answer recommends splitting `TenantStore` along knowledge lines: blob storage (content addressing, on-disk blob format, compression, file layout, `get`/`put`/`delete`) in one module, and tenant accounting/billing (plan limits, usage totals, quota enforcement, pricing and `invoice_line` formatting) in another, AND justifies it in design terms: the two parts own unrelated knowledge (byte format vs. plan/pricing policy), change for different reasons or at different rates, and can talk through a small interface such as "tenant used/freed N bytes" or "may tenant store N more bytes?". Noting that `price_per_gb_cents` in the storage constructor is a sign of the mix is a plus but not required.

FAIL if the answer recommends keeping everything in one module, splits it some other way (e.g. by read path vs. write path, or one file per method) as its main proposal, or proposes splitting purely because the file is long without naming the distinct knowledge each side owns.
