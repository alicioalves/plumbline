# naming-obviousness evals

Eval suite for the `naming-obviousness` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/naming-obviousness --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/naming-obviousness/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs 2 times per arm. Keep the judge on a different model (`sonnet`).

## What it measures

`naming-obviousness` should apply the isolation test to wide-scope names, catch one name used for two meanings, treat a hard-to-name function as a design signal rather than a vocabulary problem, and flag code whose behavior violates what its name promises. It should not fire on a request to rename one variable to a name the user already chose.

| Case | Shape | Planted problem |
|---|---|---|
| `01-session-cache` | "Hard to follow on first read", Go session cache | vague wide-scope names (`Process`, `Handle`, `flag`, package-level `m`); `ttl` is a duration in `Config` but an absolute expiry in `entry` (and `id` is a session ID in one function, a user ID in another) |
| `02-hard-to-name` | "Can't come up with a good name for this", Rust token manager | `process_and_update` is hard to name because it does five jobs (split, don't rename); `is_valid(&mut self)` silently refreshes over the network and writes to disk |
| `03-neg-rename-var` | "Rename `d` to `record`", Python: should **not** trigger the skill | none (`proc`, `x`, `conv` are bait) |

## Graders

- **One grader per planted problem (weight 1).** Did the answer find it with the naming framing (isolation test, consistency, hard-to-name means split, violated expectations) and give specific fixes, not generic restatements?
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from `red-flags/07-units-leak`; penalize generic review noise.
- **`skill-fired`.** Checks that `naming-obviousness` itself was invoked. Display-only.
- **Negative case:** `renamed` (every `d` becomes `record`, nothing else changes), `stays-on-task` (no naming review), and `skill-not-fired`.

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-session-cache | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-hard-to-name | 1.00 | 0.81 | +0.19 | 2/2 |
| 03-neg-rename-var | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.06** | |

`02-hard-to-name`: the first run scored the with-arm 0.62 because the grader only accepted *splitting* the function, while the with-plugin answer restructured it the other way (pulling the request half in so it becomes one whole `refresh`). The grader now accepts any boundary change that makes the name easy; the row shows the re-run.

## When to re-run

Re-run after any change to `skills/naming-obviousness/SKILL.md`, or to the description of `comments-docs`, which competes for "this code is hard to understand" prompts. When the numbers move, record them in the Baseline section.
