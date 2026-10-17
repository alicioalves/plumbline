---
type: llm
focus: last_message
---
PASS if the answer identifies that the Node, Python and WASM bindings each re-implement the same knowledge that belongs to the core — the format-name parsing (`parse_format`), the reverse mapping (`format_name`), the error-code table (`map_err`) and/or the field-by-field options merge — AND frames the fix as the core owning that vocabulary (for example `FromStr`/`Display` or a `name()` on `Format`, an `Error::code()`, a partial-options/patch type with a merge in core), so that adding a format or error variant no longer requires editing every binding. Noting the "Same [Code] message convention as the Node binding" comment as evidence of this leak counts in favor. FAIL if the duplication is missed, or if the only fix offered is a shared helper/macro inside the bindings with no point about the core owning the vocabulary.
