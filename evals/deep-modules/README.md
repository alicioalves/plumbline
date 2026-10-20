# deep-modules evals

Eval suite for the `deep-modules` skill. Every case runs twice: once with Plumbline installed and once without. The headline number is **Δ**: the with-plugin score minus the without-plugin score.

## What it measures

`deep-modules` should judge whether an interface is simple relative to what sits behind it. On clunky APIs it should name the shallow modules, over-decomposition and pass-throughs, and propose a deeper interface rather than local tidying. On a plain bug fix that happens to sit next to a thin wrapper, it should not fire and should just fix the bug.

## Run

```bash
claude plugin eval . --eval-dir evals/deep-modules --ablation with-without --judge-model sonnet --no-publish --trust-plugin -j 4
```

- Reports go to `evals/deep-modules/results/`, which is gitignored.
- Add `--case '02-*'` to run a single case. Only `*` wildcards work.
- Every case pins the agent to `model: opus` and runs twice per arm. Keep the judge on a different model (`sonnet`).

## Cases

| Case | Shape | Planted problem |
|---|---|---|
| `01-upload-sdk` | "Using it feels clunky, thoughts on the API?", TypeScript SDK and two call sites | Six tiny classes that callers must compose in a fixed sequence for one upload (classitis); `ChunkUploader` and `UploadFinalizer` only forward to `StorageGateway` |
| `02-service-config` | "Adding a setting is too much ceremony", Go service | `Config` mirrors a string map, so every consumer knows keys, parses and applies defaults (inconsistently); `cfg` threaded through `run`/`newRouter` as a pass-through variable |
| `03-neg-lru-recency` | Bug fix: should **not** trigger | None. `get` doesn't refresh recency; nearby `CachedPriceLookup` forwarding methods are a distractor |
| `04-clean-go-atomicfile` | "Does this interface hold up, or is it too thin?", clean Go code, tagged `clean` | none — answer should say it's sound without inventing structural problems |

The code for each case is inlined in its prompt. The prompts describe a symptom, not the diagnosis, and don't use the book's vocabulary.

## Graders

- **One grader per planted problem (weight 1).** Each requires the design framing (shallow module, pass-through) and a deepening fix, not just a mention.
- **`headline-not-generic`, `design-outweighs-generic` (weight 0.33 each).** Penalize generic review noise (style, types, tests, perf).
- **`skill-fired`.** Display-only check that `deep-modules` itself was invoked.
- **Negative case:** a correct fix, the answer stays on the bug, and `skill-not-fired` (`deep-modules` invoked zero times).

## Baseline

v1.5.0 (branch `feat/evals-all-skills`), run on 2026-10-17: 3 cases × 2 runs × 2 arms, Opus agent, Sonnet judge, `-j 4`.

| Case | With | Without | Δ | Skill fired (with) |
|---|---|---|---|---|
| 01-upload-sdk | 1.00 | 1.00 | +0.00 | 2/2 |
| 02-service-config | 1.00 | 0.56 | +0.44 | 0/2 |
| 03-neg-lru-recency | 1.00 | 0.75 | +0.25 | 2/2 correct (stayed off) |
| **Mean** | | | **+0.23** | |

`deep-modules` didn't fire on `02-service-config` (0/2), yet Δ is +0.44: the descriptions steer the answer just by being in context.

## When to re-run

Re-run after any change to `skills/deep-modules/SKILL.md`, or to the descriptions of the skills that compete for its triggers: `abstraction-quality` and `module-boundaries` (named in its "Not for" clause), plus `pull-complexity-down` and `red-flags`, which also claim pass-throughs and caller burden. When the numbers move, record a baseline above.
