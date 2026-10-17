# module-boundaries evals

Eval suite for the `module-boundaries` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## What it measures

`module-boundaries` should answer merge-or-split questions by asking what knowledge each module owns, not by size or "single responsibility". It should recommend merging when pieces are always used together and share a format, recommend splitting when a module mixes unrelated knowledge, and place the new boundary so each side fully owns its decisions. On a small feature request in a two-module codebase, it should not fire.

## Run

```bash
claude plugin eval . --eval-dir evals/module-boundaries --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/module-boundaries/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs twice per arm. Keep the judge on a different model (`sonnet`).

## Cases

| Case | Shape | Planted problem |
|---|---|---|
| `01-notifier-split` | "I split it, teammate says merge it back. Who's right?", Python, 3 classes + 2 call sites | The split is false: every caller runs select → render → fill `to` → dispatch, and the channel set and payload dict format are known by all three classes |
| `02-tenant-store` | "Should I break up store.rs, and where?", Rust | Blob storage and tenant quota/billing share a struct but no knowledge (split them); the new boundary must keep the blob format and stored-size calculation on the storage side |
| `03-neg-percent-coupon` | Small feature: should **not** trigger | None. Add the `percent` coupon branch to `computeTotals` |

The code for each case is inlined in its prompt. The prompts ask the merge/split question without hinting at the answer.

## Graders

- **One grader per planted problem (weight 1).** Each requires the verdict or boundary to be justified by knowledge ownership, not by size or SRP slogans.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Penalize generic review noise.
- **`skill-fired`.** Display-only check that `module-boundaries` itself was invoked.
- **Negative case:** a correct implementation, the answer stays on the feature, and `skill-not-fired` (`module-boundaries` invoked zero times).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-notifier-split | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-tenant-store | 0.25 | 0.25 | +0.00 | 2/2 |
| 03-neg-percent-coupon | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.00** | |

`02-tenant-store` scores 0.25 in both arms: `size-owned-by-storage` asks for a specific boundary detail (where the stored-size calculation lives) that answers in both arms skip. It doesn't move Δ.

## When to re-run

Re-run after any change to `skills/module-boundaries/SKILL.md`, or to the descriptions of the skills that compete for its triggers: `deep-modules` and `abstraction-quality` (named in its "Not for" clause), plus `information-hiding`, whose description sends merge/split decisions here. When the numbers move, record a baseline above.
