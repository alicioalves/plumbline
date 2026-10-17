---
type: llm
focus: last_message
---
PASS if the answer identifies that the Redis key scheme `sess:{user_id}:{device_id}` is known outside `SessionStore`: `accounts/security.py` and `admin/devices.py` build `sess:{user_id}:*` patterns, `admin/devices.py` parses the device id back out with `key.split(":", 2)`, and `ops/metrics.py` scans `sess:*`, AND frames it as a design problem: a storage decision that should be private to the store is encoded in other modules' implementations with nothing in the store's interface declaring it (information leakage / back-door leakage, or equivalent), which is why the migration is not a one-file change, AND recommends moving those operations into the store (e.g. `destroy_all(user_id)`, `list_sessions(user_id)`, `count_active()`) so the key scheme lives in one place.

FAIL if the answer only lists the files that need updating without identifying the key format as leaked knowledge, or recommends keeping the scans in the callers (e.g. a shared `KEY_PREFIX` constant alone) as the main fix.
