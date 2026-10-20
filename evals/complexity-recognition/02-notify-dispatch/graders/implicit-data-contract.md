---
type: llm
focus: last_message
---
PASS if the answer identifies that `rateLimitKey` always reads `n.Data["to"]`, which only email notifications set — SMS uses `"phone"` and push uses `"device_token"` — so every SMS (and every push) notification gets the same key (`"1:"` / `"2:"`) and all users share one rate-limit bucket per channel, AND ties this to the underlying design problem: the per-channel required keys of the untyped `Data map[string]string` are an implicit, undocumented contract that a developer can only learn by reading every function (obscurity, hidden dependency, unknown unknowns, high cognitive load, or equivalent), AND proposes a fix that makes the contract explicit (e.g. typed per-channel recipient/address fields, or a channel type that owns its recipient key and rate-limit key).

FAIL if the `rateLimitKey` shared-bucket defect is missed, or if it is reported only as a one-line bug fix (switch on channel inside `rateLimitKey`) with no point about the untyped map's implicit contract.
