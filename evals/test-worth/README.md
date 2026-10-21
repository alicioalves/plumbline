# test-worth evals

Eval suite for the `test-worth` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/test-worth --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/test-worth/results/`, which is gitignored.
- Add `--case '01-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` with `runs: 2`. Keep the judge on a different model (`sonnet`).
- Do not start a run unless asked. A full run is on the order of a few dollars.

## What it measures

`test-worth` decides whether a test earns its place. On tests that lock the implementation it should refuse `keep` and name the caller-visible behavior. On a request for new tests it should reject private-method and getter tests. On a failing test the user wants fixed, it should not fire. On output tests of domain behavior it should say they earn their keep.

| Case | Shape | What it tests |
|---|---|---|
| `01-mock-lock` | "Are these tests locking us in?", order service and its tests | In-process mock call-order assertions are `rewrite` or `delete`, not `keep`. Records name the observable behavior. No new runner, coverage service, or mutation run |
| `02-what-to-write` | "What tests should I add?", pricing module with no tests | Behaviors, not methods. A private-method or getter test is `don't-write`. One scenario per proposed test |
| `03-neg-failing-test` | "This test fails, fix the bug" | Should **not** fire. Fix the off-by-one |
| `04-clean-output-tests` | "Do these tests earn their keep?", tagged `clean` | Output tests of domain behavior. The answer says `keep` |
| `05-holdout-characterization` | Untested parser the user must change, tagged `holdout` | Pins observed output. Does not publish private state |

`05-holdout-characterization` is for checking trigger changes. Do not read it while tuning the description. Run it with `--tag holdout` at the end.

## Graders

- **One grader per planted decision (weight 1).**
- **`skill-fired` / `skill-not-fired`.** Display-only on the positive and clean cases (`skill-fired` has no weight). On the negative case, `skill-not-fired` is scored.

## When to re-run

Re-run after any change to `skills/test-worth/SKILL.md`, especially its `description`, or to the description of a skill it names: `apply-fixes`, `red-flags`. When the numbers move, record the baseline here.
