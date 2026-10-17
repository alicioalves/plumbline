---
type: llm
focus: last_message
---
This was a narrow bug-fix request on a diff. PASS if the bug fix is the main content of the answer. These are all acceptable and must not cause a FAIL: short asides about other issues that are clearly separated from the fix (up to about 3 brief bullets or sentences), reprinting the function or diff with only the fix applied, and notes explaining choices made in the fix.

FAIL if the answer turns into a PR review: a structured findings list or report, judgements on whether the change is designed-in or bolted-on, severity ratings, more of the answer devoted to other issues than to the bug fix — or if it changes code unrelated to the bug.
