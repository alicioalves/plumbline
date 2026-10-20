# strategic-mindset evals

Eval suite for the `strategic-mindset` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/strategic-mindset --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/strategic-mindset/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` with `runs: 2`. Keep the judge on a different model (`sonnet`).
- Cost has not been measured yet.

## What it measures

`strategic-mindset` should judge code written under pressure by its **trajectory**, not by whether it works today: spot the tactical patterns (copy-paste specials, workarounds layered on workarounds, TODO shortcuts that became permanent), project what the next changes will cost if the pattern continues, and recommend a **concrete, scoped investment** with timing. It should not fire on a small feature request in a scrappy script.

| Case | Shape | What it tests |
|---|---|---|
| `01-export-variants` | "Shipped fast last quarter, is it holding up?", TypeScript | Per-customer copies of the CSV export dispatched by org ID; regex post-processors patching dates and quotes in the finished CSV; a scoped investment plan before the next two customer formats |
| `02-webhook-ingest` | "Rushed before launch, keep building on it?", Rust | `with_retry` sniffing error strings and treating any duplicate-key error as success in place of idempotency; three copy-pasted payment handlers; a scoped investment plan before subscriptions/disputes |
| `03-neg-dry-run` | "Add a `--dry-run` flag", Python script with TODOs | Should **not** trigger a debt assessment: just the flag |
| `04-clean-py-retention` | "Written under a deadline, did we cut corners?", clean Python code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

The code for each case is inlined in its prompt. The prompts don't hint at the problems.

## Graders

- **One grader per planted problem (weight 1).** Each requires the concrete pattern, the tactical-vs-strategic framing (why it compounds), and a designed alternative.
- **`investment-plan` (weight 1).** A trajectory verdict plus a concrete first step, rough effort, and timing. Vague "refactor when you can" fails.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from the red-flags suite; penalize generic review noise.
- **`skill-fired`.** A display-only check that `strategic-mindset` was invoked. It's reported but never scored.
- **Negative case:** a correct `--dry-run`, the answer stays on the flag, and `skill-not-fired` (min 0, max 0).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-export-variants | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-webhook-ingest | 0.59 | 0.73 | -0.14 | 0/2 |
| 03-neg-dry-run | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **-0.05** | |

`02-webhook-ingest` Δ −0.14: both arms lead with money-correctness bugs, and `copy-paste-handlers` fails in both. Watch it on the next run.

## When to re-run

Re-run after any change to `skills/strategic-mindset/SKILL.md`, or to the description of a skill that competes for the same triggers: `code-evolution` (judging a specific diff), `red-flags` (its Tactical Momentum flags), and `diagnose` (routes "written under pressure" here). When the numbers move, update the baseline above.
