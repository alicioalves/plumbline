# information-hiding evals

Eval suite for the `information-hiding` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## What it measures

`information-hiding` should find design decisions (formats, key schemes, representations) known by more than one module, including back-door dependencies with no API link, and recommend a single owner behind an abstract interface. It should see through accessors that make "private" state public. On a request to explain a function, it should not fire, even when the code has a duplicated format nearby.

## Run

```bash
claude plugin eval . --eval-dir evals/information-hiding --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/information-hiding/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs twice per arm. Keep the judge on a different model (`sonnet`).

## Cases

| Case | Shape | Planted problem |
|---|---|---|
| `01-audit-export` | "Adding one field touches every file, better structure?", Go package + consumer | Read/transform/write split by execution step, with the line format shared through `[][]string`; `siem.CountDenied` reads the export CSV by column index with no shared definition |
| `02-session-migration` | "Moving Redis → Postgres, one-file change?", Python | The `sess:{user}:{device}` key scheme is built and parsed in three other modules; the `client` property exposes the raw Redis connection and stored representation |
| `03-neg-explain-frame` | "Explain what `parse_frame` returns": should **not** trigger | None. `write_frame` re-encodes the header layout and magic number as a distractor |

The code for each case is inlined in its prompt. The prompts describe the change the user is facing, not the leak.

## Graders

- **One grader per planted problem (weight 1).** Each requires naming the leaked decision, the modules that share it, and a fix that gives it one owner.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Penalize generic review noise.
- **`skill-fired`.** Display-only check that `information-hiding` itself was invoked.
- **Negative case:** a correct explanation, the answer stays on the question, and `skill-not-fired` (`information-hiding` invoked zero times).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-audit-export | 1.00 | 0.44 | +0.56 | 0/2 |
| 02-session-migration | 1.00 | 1.00 | +0.00 | 0/2 |
| 03-neg-explain-frame | 0.50 | 0.50 | +0.00 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.19** | |

`03-neg-explain-frame` fails `stays-on-task` in both arms (the judge reads the extra wire-format notes as going beyond the question). It doesn't move Δ.

## When to re-run

Re-run after any change to `skills/information-hiding/SKILL.md` or its `references/back-door-leakage.md`, or to the descriptions of the skills that compete for its triggers: `module-boundaries` and `general-vs-special` (named in its "Not for" clause), plus `pull-complexity-down`, which sends knowledge leakage here. When the numbers move, record a baseline above.
