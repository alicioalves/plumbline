# code-evolution evals

Eval suite for the `code-evolution` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/code-evolution --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/code-evolution/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` with `runs: 2`. Keep the judge on a different model (`sonnet`).
- Cost has not been measured yet.

## What it measures

`code-evolution` reviews a diff or PR and asks whether the system now looks **as if it had been designed with this change in mind**: it should catch special cases and flags bolted onto existing code, repetition the change introduces, and comments the change left stale, and propose the designed-in shape. It should not fire when the user asks for a narrow bug fix inside a diff.

| Case | Shape | What it tests |
|---|---|---|
| `01-trial-quota` | "Review this PR before I merge", TypeScript | An `isTrial` flag threaded through `limitFor`/`checkQuota` that every caller computes itself (untouched callers give trials full limits); trial caps and expiry written twice |
| `02-sftp-backups` | "PR review please, tests pass", Go | `sftp://` prefix branches prepended to `Upload`, `Verify` and `Prune` instead of a destination abstraction; the retry loop copied for SFTP; `Upload`'s doc comment still says S3/`key` |
| `03-neg-fix-continuation` | "CI fails on this diff, fix the bug", Rust | Should **not** trigger a PR review: just replace the `unwrap()` with the `OrphanContinuation` error |

The diffs are inlined in the prompts. The prompts don't hint at the problems.

## Graders

- **One grader per planted problem (weight 1).** Each requires the concrete change, the designed-in vs bolted-on (or repetition) framing, and a fix that changes the shape rather than patching more callers.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from the red-flags suite; penalize generic review noise.
- **`skill-fired`.** A display-only check that `code-evolution` was invoked. It's reported but never scored.
- **Negative case:** a correct fix, the answer stays on the bug, and `skill-not-fired` (min 0, max 0).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-trial-quota | 0.94 | 0.88 | +0.06 | 2/2 |
| 02-sftp-backups | 0.73 | 0.55 | +0.18 | 0/2 |
| 03-neg-fix-continuation | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.08** | |

`02-sftp-backups` scores lower in both arms; `code-evolution` didn't fire there (0/2).

## When to re-run

Re-run after any change to `skills/code-evolution/SKILL.md`, or to the description of a skill that competes for the same "review this diff/PR" triggers: `strategic-mindset` (overall design investment), `red-flags` (its diff-review case overlaps), and `design-review` (prioritized PR assessments). When the numbers move, update the baseline above.
