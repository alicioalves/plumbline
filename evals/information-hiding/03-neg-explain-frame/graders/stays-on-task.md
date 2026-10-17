---
type: llm
focus: last_message
---
This was a narrow request to explain what a function returns. PASS if the explanation of `parse_frame`'s return values and how `next_frame` uses them is the main content of the answer. These are all acceptable and must not cause a FAIL: short asides about other issues that are clearly separated from the explanation (up to about 3 brief bullets or sentences), small code excerpts or a walk-through example, and notes on edge cases of the code being explained.

FAIL if the answer turns into a design review: a structured findings list or report, smell categories, severity ratings, or more of the answer devoted to other issues (for example `write_frame` duplicating the header layout and magic number) than to the explanation — or if it rewrites code the user didn't ask to change.
