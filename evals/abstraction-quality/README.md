# abstraction-quality evals

Eval suite for the `abstraction-quality` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## Run

```bash
claude plugin eval . --eval-dir evals/abstraction-quality --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/abstraction-quality/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs 2 times per arm. Keep the judge on a different model (`sonnet`).

## What it measures

`abstraction-quality` should test whether each layer gives callers a genuinely different way of thinking, or is a thin rephrasing of its neighbour, and whether a clean-looking interface hides something callers depend on. It should not fire on a narrow bug fix that happens to sit inside a wrapper.

| Case | Shape | Planted problem |
|---|---|---|
| `01-mirrored-layers` | "The layering feels redundant", TypeScript repo / service / routes | `SubscriptionService` mirrors `SubscriptionRepository` method-for-method; the lifecycle rules it should own sit in the HTTP handlers |
| `02-leaky-eventlog` | "Does this abstraction hold up?", Go event log | `Log.Append` returns before the event is durable and `Flush` isn't on the interface (abstraction omits a detail callers need); `RetryingLog` forwards 3 of 4 methods to add retry to one |
| `03-neg-cache-miss` | Bug fix in a caching wrapper, Python: should **not** trigger the skill | none (the wrapper's pass-through `list_prefix` is bait) |

## Graders

- **One grader per planted problem (weight 1).** Did the answer find it, framed as an abstraction problem (same-level layers, false abstraction, decorator adding no depth) with a fix that changes what the layer offers?
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Copied from `red-flags/07-units-leak`; penalize generic review noise.
- **`skill-fired`.** Checks that `abstraction-quality` itself was invoked. Display-only.
- **Negative case:** `fixes-bug` (the fix is correct), `stays-on-task` (no design review), and `skill-not-fired` (the skill is not invoked).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-mirrored-layers | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-leaky-eventlog | 0.75 | 0.56 | +0.19 | 2/2 |
| 03-neg-cache-miss | 1.00 | 1.00 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.06** | |

`02-leaky-eventlog` fails `retry-decorator` in both arms.

## When to re-run

Re-run after any change to `skills/abstraction-quality/SKILL.md`, or to the descriptions of the skills that compete for its triggers: `deep-modules` (a single module's interface-to-implementation ratio, pass-through audits) and `information-hiding` (leakage across boundaries). When the numbers move, record them in the Baseline section.
