---
type: llm
focus: last_message
---
PASS if the answer identifies that `display_price` reads the module-global `_fx_rates`, which is only populated as a side effect of `invoice_total`, so in a process where `invoice_total` has not run (e.g. the pricing page), `display_price` silently falls back to a rate of 1 and shows a USD amount labelled with another currency (or shows stale rates from whenever the last invoice ran), AND frames it as a design problem: a hidden dependency / implicit ordering constraint / unknown unknown — nothing in either function's interface reveals that one depends on the other having run — AND proposes a fix that makes the dependency explicit or encapsulated (e.g. both functions get rates from a rates provider/cache that owns fetching, rates passed as a parameter, removing the silent `get(..., 1)` default).

FAIL if the coupling is missed, or if it is only described as "global variables are bad style" or a thread-safety nit with no mention of the concrete wrong-price consequence.
