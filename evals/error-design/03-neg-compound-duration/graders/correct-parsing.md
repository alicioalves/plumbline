---
type: llm
focus: last_message
---
PASS if the answer shows an updated `parseDuration` that, judged by reading the code: returns 5400000 for `"1h30m"`, 150500 for `"2m30s500ms"` (the `ms` unit must not be misread as `m` followed by `s`), and still 90000 for `"90s"`; throws `InvalidDurationError` for inputs with leftover or unmatched text such as `"1h30"`, `"abc"`, `"1hx"` or `"h"` (the whole string must be consumed, not just scanned for matches); and keeps the existing empty, negative and overflow checks. FAIL if any of these would behave differently, or if the change is only described in prose without code.
