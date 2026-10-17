# complexity-recognition evals

Eval suite for the `complexity-recognition` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/complexity-recognition --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/complexity-recognition/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` with `runs: 2`. Keep the judge on a different model (`sonnet`).
- Cost has not been measured yet.

## What it measures

`complexity-recognition` is the entry point when code "feels harder than it should" and the user can't name the problem. It should **name the symptoms** (change amplification, cognitive load, unknown unknowns), **trace them to a root cause** (dependencies or obscurity), and tie both to concrete lines of the code, rather than returning a generic review. It should not fire on a plain "explain this function" request.

| Case | Shape | What it tests |
|---|---|---|
| `01-plan-pricing` | "Harder to work with than it should be, can't say why", Python | Plan facts spread over parallel position-indexed lists and plan-name if-chains (change amplification); `display_price` silently depends on `_fx_rates` filled as a side effect of `invoice_total` (hidden dependency) |
| `02-notify-dispatch` | "Nobody wants to touch it, new people ship bugs", Go | Per-channel behaviour split over four `switch` statements (change amplification); untyped `Data` map whose per-channel keys are an implicit contract, so `rateLimitKey` puts every SMS and push user in one bucket (obscurity / unknown unknown) |
| `03-neg-explain-coalesce` | "Walk me through this function", TypeScript | Should **not** trigger a complexity diagnosis: just an accurate explanation |
| `04-clean-py-rollouts` | "Feels like it'll be hard to work with, can't say why", clean Python code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

The code for each case is inlined in its prompt. The prompts don't hint at the problems.

## Graders

- **One grader per planted problem (weight 1).** Each requires the concrete defect *and* the design framing (which symptom, which root cause) *and* a fix that removes or encapsulates the cause.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from the red-flags suite; penalize generic review noise.
- **`skill-fired`.** A display-only check that `complexity-recognition` was invoked. It's reported but never scored.
- **Negative case:** an accurate explanation, the answer stays an explanation, and `skill-not-fired` (min 0, max 0).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-plan-pricing | 1.00 | 0.94 | +0.06 | 2/2 |
| 02-notify-dispatch | 0.94 | 1.00 | -0.06 | 2/2 |
| 03-neg-explain-coalesce | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.00** | |

`02-notify-dispatch` with-arm missed `headline-not-generic` once; Δ −0.06 is within run-to-run noise.

## When to re-run

Re-run after any change to `skills/complexity-recognition/SKILL.md`, or to the description of a skill that competes for the same triggers: `red-flags` (known smells), `deep-modules` (module depth), `diagnose` (routes vague symptoms here), and `design-review` (full reviews). When the numbers move, update the baseline above.
