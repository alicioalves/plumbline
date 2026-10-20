---
type: llm
focus: last_message
---
PASS if the answer identifies that `load` exposes three exception types (`FlagFileMissing`, `FlagFileCorrupt`, `FlagSchemaError`) that the only caller handles identically (log a warning, run with all flags off), AND recommends reducing that surface: either aggregate them into one exception (e.g. catch `FlagError` or a single `FlagLoadError` in one place) or mask them inside the store by making "fall back to no flags, with a logged warning" part of `load`'s specified behavior. A good answer may also note the trade-off that a corrupt file silently disabling every flag may deserve to be loud, which is fine. FAIL if the three load exceptions are not raised as an issue, or are only reformatted (e.g. `except (A, B, C):`) without any point about the size of the error interface.
