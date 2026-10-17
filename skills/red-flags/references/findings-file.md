# The findings file

`.plumbline/findings.md` is an optional file in the reviewed project that remembers design findings between reviews. It lives in the project's repository, so the whole team shares it and its history shows how the design debt moved.

Nothing creates it silently. After a review with triggered flags, offer once to save them; create the file only if the user agrees. Once it exists, keep it current: **red-flags** and **design-review** update it after each review, **apply-fixes** marks what it fixed, and **code-evolution** checks changes against it.

## Format

One section per finding. The heading is a stable **slug** that names the concept, not a location, so the entry survives refactors and line changes:

```markdown
# Plumbline findings

## adapter-vocabulary
- flag: 18 Vocabulary Not Owned
- where: `parse_format`, `format_name`, `map_err` in the node, python and wasm bindings
- status: open
- first seen: 2026-10-17
- last seen: 2026-11-02
- note: core should expose `FromStr`/`name()`/`Error::code()`

## icc-best-effort
- flag: 17 Catch-and-Ignore
- where: `apply_icc_best_effort` in core/src/color.rs
- status: accepted
- first seen: 2026-10-17
- reason: the image already decoded; failing the whole call over a broken color profile is worse for users
```

- **slug**: lowercase words joined by `-`, describing the problem (`adapter-vocabulary`, `bytes-in-caller-burden`). Reuse the existing slug when the same problem shows up again.
- **where**: symbols, types, modules or files, never line numbers.
- **status**: `open`, `fixed` or `accepted`.
- **reason** is required for `accepted`. An accepted entry with a reason counts as the explicit rationale the ACCEPTED state needs, so the flag is listed as accepted instead of reported again.
- **fixed** entries stay in the file (with a `fixed: <date>` line) so a later change that brings the problem back can be recognized.

## Reconciling a review with the file

Match each triggered flag to an entry by concept (same flag and the same symbols or knowledge), not by exact wording.

| Review says | File says | Report as | Update |
|---|---|---|---|
| triggered | no entry | **new** | add an `open` entry |
| triggered | `open` | **still open since <first seen>** | bump `last seen` |
| triggered | `accepted` | accepted (one line), unless the reason no longer holds | none, or set `open` and say why the reason stopped holding |
| triggered | `fixed` | **regressed**: fixed on <date>, back again | set `open`, keep the history |
| not triggered | `open` | **fixed since last review** | set `fixed` with today's date |

Put **new** and **regressed** first in the report; they are what changed. Keep "still open" to one line each.
