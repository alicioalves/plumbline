---
type: llm
focus: last_message
---
This was a narrow bug-fix request. PASS if the bug fix is the main content of the answer. These are all acceptable and must not cause a FAIL: short asides about other issues that are clearly separated from the fix (up to about 3 brief bullets or sentences), reprinting the function with only the fix applied, and notes explaining choices made in the fix.

FAIL if the answer turns into a design review: a structured findings list or report, smell categories, severity ratings, or more of the answer devoted to other issues (for example the `capForMobile` parameter) than to the bug fix — or if it changes code unrelated to the bug, such as removing or restructuring `capForMobile`.
