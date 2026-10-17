---
type: regex
target: { source: file, path: service.py }
match: not_contains
---
retries|timeout|notify
