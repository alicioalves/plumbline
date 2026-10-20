---
type: llm
focus: last_message
---
PASS if the answer identifies at least three of these names as too vague to convey what the entity is when read on its own (isolation test, vague or generic name, or equivalent) and proposes a specific replacement that says what each one actually means: `Process` (parses session claims and looks up or creates the cached session), `Handle` (actually revokes/deletes a session), `flag` (a recently-used / second-chance bit consulted by `sweep`), the package-level `m` (sessions keyed by session ID), `data`/`Info`, `d`/`tmp`. At least two of the three must come from `Process`, `Handle`, `flag`, `m`, since those have the widest scope or the most misleading meaning. FAIL if fewer than three are raised, or if renames are generic restatements (e.g. `Handle` → `HandleSession`) that still do not say what the function does.
