---
type: llm
focus: last_message
---
This was a narrow question asking what one function does. PASS if the explanation of `coalesce` and the worked example are the main content of the answer. These are all acceptable and must not cause a FAIL: short asides clearly separated from the explanation (up to about 3 brief bullets or sentences), including a one-line suggestion that the doc comment could say this, and a short note on how it affects `read_plan`.

FAIL if the answer turns into a review: a structured findings list or report, smell categories, severity ratings, a rewritten set of doc comments for the module, or more of the answer devoted to other issues than to explaining `coalesce` — or if it rewrites the code when no change was asked for.
