# general-vs-special evals

Eval suite for the `general-vs-special` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/general-vs-special --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/general-vs-special/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs 2 times per arm. Keep the judge on a different model (`sonnet`).

## What it measures

`general-vs-special` should spot caller-specific knowledge baked into a shared module, at the interface (one-caller parameters and methods) or in the body (special cases every caller must handle), and getters/setters that expose representation instead of doing work. It should not fire on a narrow bug fix in a module that happens to carry a special-purpose flag.

| Case | Shape | Planted problem |
|---|---|---|
| `01-order-query` | "Is this interface still the right shape?", Python query helper + 3 callers | `search` grows one flag per caller (`for_admin_panel`, `mobile_client`, `include_line_items_for_export`); returns `None` for no rows so every caller special-cases it |
| `02-playlist` | "Right interface before other teams depend on it?", TypeScript | getters/setters expose `tracks` and `currentIndex`, so callers re-implement index bookkeeping; `addTrackForRadioMode` bakes one feature's policy into the shared class |
| `03-neg-open-range` | Bug fix in an HTTP Range parser, Go: should **not** trigger the skill | none (the `capForMobile` parameter is bait) |
| `04-clean-rust-text-buffer` | "Is this interface general enough, or do I need editor-specific methods?", clean Rust code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

## Graders

- **One grader per planted problem (weight 1).** Did the answer find it, framed as a generality problem, with a fix that pushes specialization to the callers or replaces data access with operations?
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from `red-flags/07-units-leak`; penalize generic review noise.
- **`skill-fired`.** Checks that `general-vs-special` itself was invoked. Display-only.
- **Negative case:** `fixes-bug` (the fix is correct), `stays-on-task` (no design review, `capForMobile` left alone), and `skill-not-fired`.

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-order-query | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-playlist | 1.00 | 0.81 | +0.19 | 2/2 |
| 03-neg-open-range | 0.50 | 0.50 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.06** | |

`03-neg-open-range` fails `fixes-bug` in both arms: answers also fix a second, real edge case (empty file), which the grader counts as changing another case.

## When to re-run

Re-run after any change to `skills/general-vs-special/SKILL.md`, or to the descriptions of the skills that compete for its triggers: `information-hiding` (leakage across boundaries, which also covers getter/setter audits) and `pull-complexity-down` (configuration parameters and caller burden). When the numbers move, record them in the Baseline section.
