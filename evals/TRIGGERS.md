# Trigger measurements

Whether the right skill activates is decided by the skill `description` alone, so description changes are measured here across every skill suite at once. Runs use `--ablation none` (with-plugin arm only): the no-plugin arm doesn't depend on descriptions, so the Δ baselines in each suite README still apply to it.

Case kinds: **positive** (`01`, `02`: a planted problem for that lens), **holdout** (`05`, tag `holdout`: never read while tuning), **clean** (`04`, tag `clean`: well-designed code; should fire and say it's fine), **negative** (`03`: a non-design request; the skill must stay off).

## 1.8.0 — symptom-first descriptions (2026-10-17)

Lens descriptions were rewritten to open with the symptoms users actually describe ("adding a config option is all ceremony", "one field means editing every file", "every new client gets it wrong", "PR review please"), then the book's terms. `red-flags` now defers to the matching lens when the user names a concern; `diagnose` triggers only when the user says they don't know what kind of problem it is; `diagnose` and `complexity-recognition` were told to lead with "it's fine" when it is.

13 skill suites, 5 cases × 2 runs each:

| Kind | Trigger correct before | after | Mean score before | after |
|---|---|---|---|---|
| positive | 36/52 (69%) | **48/52 (92%)** | 0.87 | **0.95** |
| holdout | 16/26 (62%) | **24/26 (92%)** | 0.81 | **0.93** |
| clean | 24/26 (92%) | **26/26 (100%)** | 0.95 | **0.97** |
| negative | 26/26 (100%) | 26/26 (100%) | 0.88 | 0.92 |

Held-out cases improved as much as the tuned ones, so the gain isn't overfitting; negatives stayed at 100%, so the wider descriptions don't fire on non-design requests. Cost: $31.93 before, $30.39 after.

`red-flags` suite (with-plugin arm) after narrowing its description: 9/11 cases at 1.00. Two moved: `03-diff-review` 0.93 → 0.88 (a diff review now goes to `code-evolution`, which found the two real bugs but not the long parameter list) and `04-pasted-ts` 1.00 → 0.94 (`root-cause` grader). Both stay far above their no-plugin scores (0.57, 0.71). `06-neg-keyerror` shows 0.75 only because `skill-fired` is scored when there is no baseline arm; the skill correctly didn't fire.
