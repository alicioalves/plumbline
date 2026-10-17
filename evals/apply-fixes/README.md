# apply-fixes evals

Eval suite for the `apply-fixes` skill. Each case scaffolds a small Python repository with `unittest` tests and one git commit, then asks Claude to apply a red-flags report (or, in the negative case, to fix a plain bug). Graders read the files Claude leaves behind and the tool calls it made.

These cases need **Bash, Edit and Write**, so they need Claude Code's sandbox: run them on **macOS, Linux or WSL2**, not native Windows. See [../MAC.md](../MAC.md).

## Run

```bash
claude plugin eval . --eval-dir evals/apply-fixes --scaffold --trust-plugin \
  --allow-tools Edit Write "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git checkout:*)" "Bash(python3 -m unittest:*)" \
  --ablation with-without --judge-model sonnet --no-publish -j 3
```

`--scaffold` runs each case's `fixture.sh` (author-written bash that creates the repo); only pass it for suites you trust.

## Cases

| Case | Shape | What it checks |
|---|---|---|
| `01-passthrough-and-params` | Report with two safe fixes | Both applied (`service.py` no longer has the pass-through or the unused parameters), `app.py` callers updated, tests run more than once, nothing committed |
| `02-unsafe-fix-reverted` | Report whose first fix breaks a case-insensitivity test | The bad fix is reverted and reported, the independent safe fix is still applied, tests run more than once, nothing committed |
| `03-neg-bugfix` | "signup crashes with KeyError, fix it" | `apply-fixes` does not fire, the bug is fixed, the unrelated design issues are left alone |

## Baseline

Not run yet.

## When to re-run

After any change to `skills/apply-fixes/SKILL.md`, or to the descriptions of `red-flags`, `design-review` and `diagnose`, which point to it.
