---
type: llm
focus: last_message
---
This was a narrow bug-fix request. PASS if the bug fix is the main content of the answer. These are all acceptable and must not cause a FAIL: short asides about other issues that are clearly separated from the fix (up to about 3 brief bullets or sentences), reprinting the file with only the fix applied, and notes explaining choices made in the fix (such as switching the field to a `time.Duration`).

FAIL if the answer turns into a design review: a structured findings list or report, smell categories, severity ratings, or more of the answer devoted to other issues (for example how many knobs `Options` exposes or the `Insecure` flag) than to the bug fix — or if it changes code unrelated to the bug.
