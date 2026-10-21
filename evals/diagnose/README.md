# diagnose evals

Eval suite for the `diagnose` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/diagnose --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/diagnose/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` with `runs: 2`. Keep the judge on a different model (`sonnet`).
- Cost has not been measured yet.

## What it measures

`diagnose` takes a vague symptom ("every new provider touches six files", "I can't name this class") and routes it to the right design lens. Graders don't require the answer to name a Plumbline skill — the no-plugin arm can't — but they do require the **diagnosis that lens would give**, explained with evidence from the code, instead of a generic review or a literal answer to the surface question. It should not fire on a concrete bug report.

| Case | Shape | What it tests |
|---|---|---|
| `01-payment-providers` | "Adding a provider touches six files and we miss things", Python | Routed to information hiding: provider knowledge is scattered across checkout, refunds, webhooks, fees and the model; remedy is one adapter per provider; backed by concrete leaks (`psp_reference`, `/ 100`, fees default 0) |
| `02-unnameable-class` | "I can't come up with a name for this class", TypeScript | Routed to naming-obviousness then design-it-twice: the class does six jobs, so no name fits; propose and compare alternative decompositions instead of picking a name |
| `03-neg-nil-map` | "Panics with nil map, fix it", Go | Should **not** route anything: just initialize the map |
| `04-clean-ts-money` | "Something about it bugs me, not sure what kind of review it needs", clean TypeScript code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

The code for each case is inlined in its prompt. The prompts don't hint at the cause.

## Graders

- **`right-lens` / `naming-signals-design` (weight 1).** The answer reaches the diagnosis of the right lens and explains why it produces the reported symptom.
- **`evidence-from-code` / `alternative-decompositions` (weight 1).** The diagnosis is backed by concrete code, or (for naming) carried through to more than one candidate decomposition.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from the red-flags suite; penalize generic review noise.
- **`skill-fired`.** A display-only check that `diagnose` was invoked. It's reported but never scored. The routed-to lens firing instead of `diagnose` counts as not fired here; read the transcripts before treating a low count as a regression.
- **Negative case:** a correct fix, the answer stays on the bug, and `skill-not-fired` (min 0, max 0).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-payment-providers | 1.00 | 0.94 | +0.06 | 0/2 |
| 02-unnameable-class | 0.81 | 0.81 | +0.00 | 0/2 |
| 03-neg-nil-map | 0.75 | 0.75 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.02** | |

`diagnose` didn't fire in either positive case (0/2): the routed-to lenses or a direct answer won instead. Scores stay high, so the routing advice reaches the answer anyway. `03-neg-nil-map` fails `stays-on-task` in both arms.

## When to re-run

Re-run after any change to `skills/diagnose/SKILL.md` (especially its decision tree), or to the description of a skill that competes for the same triggers: `design-review` (comprehensive reviews), `red-flags` (its fallback and checklist scans), `complexity-recognition` (the "feels wrong" entry point), `test-worth` (branch 10, complaints about tests), and the lenses it routes to here (`information-hiding`, `naming-obviousness`, `design-it-twice`). When the numbers move, update the baseline above.
