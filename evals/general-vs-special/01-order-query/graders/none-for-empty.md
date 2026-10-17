---
type: llm
focus: last_message
---
PASS if the answer identifies that `search` returns `None` when no rows match, which forces every caller (all three shown) to add its own `is None` special case, AND recommends returning an empty list so that the special case disappears and the callers' normal code paths (iterating, rendering, the export loop's termination check on an empty page) handle it naturally. FAIL if the `None` return is not raised, or if it is raised only as a type-hint/consistency nit without the point that callers are forced to special-case it.
