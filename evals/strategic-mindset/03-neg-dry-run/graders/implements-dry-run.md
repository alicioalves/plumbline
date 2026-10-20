---
type: llm
focus: last_message
---
PASS if the answer shows an updated script (code, not just prose) in which:
- argparse accepts `--dry-run` as a boolean flag (e.g. `action="store_true"`);
- with `--dry-run`, `delete_objects` / `delete_batch` is never called, each stale object's key is printed, and the total size that would be freed is printed;
- without `--dry-run`, the script still deletes in batches of up to 1000 and prints its summary as before;
- the selection logic (`stale_objects`, `--days`, `KEEP_PREFIXES`) is unchanged.

FAIL if any of these is missing, if dry-run could still delete anything, or if the change breaks the normal path.
