# red-flags-scale evals

Cases for `red-flags` on a **repository on disk** instead of code pasted into the prompt, so they can measure what the inline suite can't: the Reading Strategy (public API, then boundaries, then only the implementations a signal points at), the Git Co-Change Test, and whether the Vocabulary Not Owned finding survives when the duplicated code is buried among ~2,000 lines of realistic filler.

They need Claude Code's sandbox (the agent runs `git log`), so run them on **macOS, Linux or WSL2**. See [../MAC.md](../MAC.md).

## Run

```bash
claude plugin eval . --eval-dir evals/red-flags-scale --scaffold --trust-plugin   --ablation with-without --judge-model sonnet --no-publish -j 3
```

## Cases

| Case | Shape | Graders |
|---|---|---|
| `01-repo-on-disk` | TypeScript monorepo: `core` + `cli`, `http`, `sdk` adapters, 26 files, 8 commits. Each adapter re-implements channel parsing/naming, error codes and option defaults, and the history shows them edited together (new channel, renamed code, changed defaults) | `vocabulary-not-owned`, `root-cause`, `reading-budget` (at most 20 Read calls), `co-change-used` (`git log` run, weight 0.5), `headline-not-generic`, `design-outweighs-generic`, `skill-fired` |

`reading-budget` and `co-change-used` are scored in both arms, so the with/without comparison shows how many reads the strategy saves.

## Baseline

Not run yet.

## When to re-run

After changes to the Reading Strategy or flag 18 in `skills/red-flags/SKILL.md`, or to the Git Co-Change Test in `skills/information-hiding/references/back-door-leakage.md`.
