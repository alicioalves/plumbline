---
type: llm
focus: last_message
---
This was a narrow request to add one flag to a script. PASS if the `--dry-run` change is the main content of the answer. These are all acceptable and must not cause a FAIL: short asides about other issues that are clearly separated from the change (up to about 3 brief bullets or sentences), reprinting the whole script with only the flag added, and notes explaining choices made in the change.

FAIL if the answer turns into a technical-debt or design assessment: a structured findings list or report, a tactical-vs-strategic verdict, an investment or refactoring plan, more of the answer devoted to other issues than to the flag — or if it changes code unrelated to the flag (e.g. moving `RETENTION_DAYS` to config, restructuring the script).
