---
type: llm
focus: last_message
---
PASS if the answer's proposed boundary keeps all knowledge of the on-disk blob format (`MAGIC`, `HEADER_LEN`, the compression flag and threshold, file paths) on the storage side, with encoding (`put`) and decoding (`get`) of that format in the same module, AND explicitly addresses where the stored-size calculation lives: the accounting side should receive byte counts from storage (e.g. `put` reports or reserves the stored size, `delete` reports what it freed, storage exposes a per-tenant size scan for `rebuild_usage`) rather than computing `HEADER_LEN + body.len()` or walking the tenant directories itself.

FAIL if the stored-size calculation or the directory walk in `rebuild_usage` is left in (or moved into) the accounting/quota module, if blob encoding and decoding end up in different modules, or if the answer proposes a split without saying how size information crosses the new boundary.
