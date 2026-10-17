# comments-docs evals

Eval suite for the `comments-docs` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/comments-docs --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/comments-docs/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs 2 times per arm. Keep the judge on a different model (`sonnet`).

## What it measures

`comments-docs` should delete comments that repeat the code and say what callers actually need instead, catch docs that no longer match the code, and read a long, heavily qualified comment as a design problem rather than a writing problem. It should not fire on a question asking what one function does.

| Case | Shape | Planted problem |
|---|---|---|
| `01-limiter-comments` | "Review the comments before we publish", TypeScript rate limiter | comments restate names/code while interface docs omit return meaning, units and window semantics; stale docs (`windowSeconds` default 60 vs `windowMs = 30_000`, `@returns null` vs a number) that the middleware trusted, so it never blocks |
| `02-reconcile-docs` | "Review the doc comments before hand-off", Go reconciler | the `Reconcile` comment is a chain of "unless"/"except" clauses, signalling a function that mixes modes behind boolean flags; `Spec` field comments restate names and omit units (`DrainTimeout` is seconds) and zero-value meaning (`MaxSurge` 0 → 1) |
| `03-neg-explain-coalesce` | "What does `coalesce` do with `gap`?", Rust: should **not** trigger the skill | none (the one-line "Merges byte ranges." doc is bait) |

## Graders

- **One grader per planted problem (weight 1).** Did the answer find it with the comments framing (repeats code, missing interface precision, comment rot, hard-to-describe as a design signal, member comments missing units and ranges) and say concretely what is missing?
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from `red-flags/07-units-leak`; penalize generic review noise.
- **`skill-fired`.** Checks that `comments-docs` itself was invoked. Display-only.
- **Negative case:** `correct-explanation` (right semantics of `gap` and the right example result, `[0..20, 40..50]`), `stays-on-task` (no review, no rewritten docs), and `skill-not-fired`.

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-limiter-comments | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-reconcile-docs | 1.00 | 0.81 | +0.19 | 2/2 |
| 03-neg-explain-coalesce | 0.50 | 0.50 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.06** | |

`03-neg-explain-coalesce` fails `stays-on-task` in both arms. It doesn't move Δ.

## When to re-run

Re-run after any change to `skills/comments-docs/SKILL.md`, or to the description of `naming-obviousness`, which competes for "this code is hard to understand" prompts. When the numbers move, record them in the Baseline section.
