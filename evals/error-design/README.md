# error-design evals

Eval suite for the `error-design` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/error-design --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/error-design/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs 2 times per arm. Keep the judge on a different model (`sonnet`).

## What it measures

`error-design` should shrink a module's error surface: define errors out of existence where callers all react the same trivial way, aggregate handling in one place instead of at every call site, and refuse to mask errors callers need. It should not fire on a narrow feature request in a module that happens to have too many exception classes.

| Case | Shape | Planted problem |
|---|---|---|
| `01-flag-store` | "Error handling is getting out of hand", Python feature-flag store + callers | `FlagNotDefined` / `FlagNotFound` / `FlagAlreadyExists` are swallowed identically by every caller (should be defined out); `load` raises three types its one caller handles identically (aggregate or mask) |
| `02-upload-handlers` | "Error handling is longer than the logic", Rust HTTP handlers | every handler matches each `ParamError`/`StorageError` variant itself (aggregate at the top with `?`); `BlobDir::save` swallows an fsync failure and returns `Ok` (masking an error the caller needs) |
| `03-neg-compound-duration` | Small feature in a TypeScript duration parser: should **not** trigger the skill | none (four error classes and a catch chain in the caller are bait) |

## Graders

- **One grader per planted problem (weight 1).** Did the answer find it and apply the right move (define out, aggregate, don't mask), not just tidy the try/except?
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from `red-flags/07-units-leak`; penalize generic review noise.
- **`skill-fired`.** Checks that `error-design` itself was invoked. Display-only.
- **Negative case:** `correct-parsing` (compound durations parse correctly and garbage is still rejected), `stays-on-task` (no review, error classes left alone), and `skill-not-fired`.

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-flag-store | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-upload-handlers | 1.00 | 1.00 | +0.00 | 2/2 |
| 03-neg-compound-duration | 0.75 | 0.50 | +0.25 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.08** | |

## When to re-run

Re-run after any change to `skills/error-design/SKILL.md`, or to the description of `pull-complexity-down`, which competes for "callers have to handle too much" prompts. When the numbers move, record them in the Baseline section.
