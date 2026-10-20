---
type: llm
focus: last_message
---
PASS if the answer identifies that the PR writes the trial rules twice — the caps (1,000 API calls, 1 GB storage, a quarter of the base for everything else) appear in both `limitFor` and `remainingQuota`, and the expiry check appears in both `checkQuota` and `remainingQuota` — AND frames it as repetition introduced by the change: the next change to trial terms must be made in multiple places and the copies can drift (e.g. `remainingQuota` already decides trial status differently from `checkQuota`), AND recommends one place that owns trial limits and expiry (e.g. `remainingQuota` and `checkQuota` both going through a single effective-limit function).

FAIL if the duplication is not raised.
