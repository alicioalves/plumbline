# Running the sandboxed evals (macOS / Linux / WSL2)

Most suites only use Read and Grep and run anywhere. Two need Claude Code's sandbox because the agent runs shell commands or edits files, so they don't run on native Windows:

- `red-flags-scale/01-repo-on-disk`: a ~2,000-line TypeScript monorepo with git history, built by `fixture.sh`. Measures the reading strategy (Read calls, `reading-budget` grader), git co-change use and the Vocabulary Not Owned finding.
- `apply-fixes/*`: small Python repos with tests, to check fixes are applied one at a time, a breaking fix is reverted, and plain bug fixes don't trigger the skill.

From the plugin root:

```bash
# reading strategy on a repo on disk (~$6)
claude plugin eval . --eval-dir evals/red-flags-scale --scaffold --trust-plugin \
  --ablation with-without --judge-model sonnet --no-publish -j 3

# apply-fixes (~$6)
claude plugin eval . --eval-dir evals/apply-fixes --scaffold --trust-plugin \
  --allow-tools Edit Write "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git checkout:*)" "Bash(python3 -m unittest:*)" \
  --ablation with-without --judge-model sonnet --no-publish -j 3
```

Requirements: `git` 2.31+, `python3`, `perl` (all present on macOS). The fixtures avoid GNU-only `sed` and bash 4 syntax so they run on the macOS defaults.

Copy the summary table each run prints into the suite's README under **Baseline**, with the date and commit.
