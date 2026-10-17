---
type: llm
focus: last_message
---
PASS if the answer identifies that `handle_invoice_paid`, `handle_invoice_paid_v2` and `handle_refund` are copies of one another that differ only in where they read fields from the JSON, each repeating the same transaction/insert/ledger sequence, AND frames this as copy-paste instead of generalization that will compound (subscriptions and disputes would add more copies; a change to how payments are recorded must be made in every copy), AND recommends separating "parse/normalize the payload for this event type and version" (e.g. into one typed struct, with the v1/v2 differences handled in parsing) from a single function that records a payment.

FAIL if the duplication is not raised, or is mentioned only as "extract a helper" without the point about the next event types multiplying it.
