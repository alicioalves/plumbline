---
type: llm
focus: last_message
---
PASS if the answer identifies that `with_retry` decides behaviour by matching on error message text — retrying on `"deadlock"` and treating any `"duplicate key"` error as success — AND frames this as a quick-fix workaround standing in for a design that was never done: idempotency (a webhook delivered twice) is handled by swallowing a constraint violation, and retry policy depends on driver message strings rather than typed error kinds — so any unrelated duplicate-key error (or a reworded driver message) is silently treated as success or failure. The answer must recommend a designed-in alternative, e.g. explicit idempotency on the event or invoice id (`ON CONFLICT DO NOTHING` / a processed-events table / idempotency key) and retry decisions on typed `DbError` variants.

FAIL if `with_retry`'s string matching is not discussed, or is only mentioned as a style nit ("use error types") with no point about the duplicate-key swallowing standing in for real idempotency.
