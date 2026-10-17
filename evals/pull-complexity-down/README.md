# pull-complexity-down evals

Eval suite for the `pull-complexity-down` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## What it measures

`pull-complexity-down` should notice where an interface makes callers do work the module could do: configuration nobody can choose well, lifecycle contracts, limits and paging protocols that every caller re-implements. It should recommend absorbing that work into the implementation, not adding helpers on the caller side. On a plain bug fix in a client with plenty of knobs, it should not fire.

## Run

```bash
claude plugin eval . --eval-dir evals/pull-complexity-down --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/pull-complexity-down/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs twice per arm. Keep the judge on a different model (`sonnet`).

## Cases

| Case | Shape | Planted problem |
|---|---|---|
| `01-conn-pool` | "New clients always go wrong, how would you reshape the API?", Rust pool + 2 clients | Five `PoolConfig` knobs both callers set identically (with an unenforced `min_idle`/`max_size` pair); callers must start maintenance and choose `release` vs `discard`, which `publish`'s `?` gets wrong |
| `02-analytics-client` | "New jobs take longer than they should", TypeScript client + 2 jobs | `RangeTooLargeError` leaves every caller to window ranges over 31 days; manual cursor pagination repeated in every job |
| `03-neg-timeout-bug` | Bug fix: should **not** trigger | None. `time.Duration(TimeoutSeconds)` is 10ns; the knob-heavy `Options` struct is a distractor |
| `04-clean-rust-pool` | "Does it ask too much of callers?", clean Rust code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

The code for each case is inlined in its prompt. The prompts describe the pain, not where the complexity should live.

## Graders

- **One grader per planted problem (weight 1).** Each requires the point that the module should absorb the complexity, not just a caller-side helper or a local fix.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Penalize generic review noise.
- **`skill-fired`.** Display-only check that `pull-complexity-down` itself was invoked.
- **Negative case:** a correct fix, the answer stays on the bug, and `skill-not-fired` (`pull-complexity-down` invoked zero times).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-conn-pool | 0.62 | 0.62 | +0.00 | 0/2 |
| 02-analytics-client | 1.00 | 1.00 | +0.00 | 1/2 |
| 03-neg-timeout-bug | 1.00 | 0.75 | +0.25 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.08** | |

`01-conn-pool` fails `config-knobs` in both arms: answers lead with the connection-leak lifecycle problem and don't argue the five knobs away. It doesn't move Δ.

## When to re-run

Re-run after any change to `skills/pull-complexity-down/SKILL.md` or its `references/configuration-parameter-audit.md`, or to the descriptions of the skills that compete for its triggers: `deep-modules`, `information-hiding` and `error-design` (named in its "Not for" clause). When the numbers move, record a baseline above.
