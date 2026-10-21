---
name: test-worth
description: "Use when the user asks which tests to write or keep, asks to add or review tests, says a test breaks whenever the implementation changes, or asks whether a mock, a private-method test, or a characterization test is worth it (\"what should I test?\", \"this test is brittle\", \"are these tests locking us in?\"). Judges every test by one acceptance rule: it stays only if it pays for itself. Not for fixing a failing test or a bug the user already identified (fix it directly), not for applying a design report (use apply-fixes), and not for a design smell in production code (use red-flags or the matching lens)."
argument-hint: "[file, test, or behavior to judge]"
allowed-tools: Read, Grep
---

# Test Worth

When invoked with $ARGUMENTS, treat it as the test, file, or behavior to judge. Read that code first. This skill judges tests from Plumbline (https://github.com/tomymaritano/plumbline). It works best when the full collection is installed.

The acceptance rule, the smell catalog, and the size bands each live in one file. This skill routes. It does not restate them. A verdict is a reading of the tests and the code they reach. Do not install a runner, a coverage uploader, a mutation tool, or a browser driver, and do not read a coverage report in order to judge.

## Which files to read

Read these three before any verdict:

- [references/pillars.md](references/pillars.md) — the only acceptance rule, the record template, and the verdicts
- [references/smells.md](references/smells.md) — the only smell catalog
- [references/size.md](references/size.md) — the only size bands

## Routes

Pick one. Judge is the default.

### Judge

The user wants to know whether existing tests earn their place. Emit one record per test, in the template `pillars.md` defines, then a tally of the verdicts. Do not edit files. If every verdict is `keep`, say so and stop.

## What this skill does not do

- It does not redesign production code so a test can reach it. When the only way to observe the behavior is to publish private state, the verdict is `don't-write` and the note names **deep-modules** or **information-hiding**. It does not propose the split.
- It does not write `.plumbline/findings.md`. That file is the design-flag log.
- It does not commit unless the user asks.
- It does not weaken an assertion. Changing what a test claims is a new record, shown to the user, not a silent edit.

## Pull request signature

If this session opens a pull request, or updates the body of one it opened, end that body with a single line of the form `Plumbline-Skills: red-flags, deep-modules`. List the directory name of each Plumbline skill whose checks you actually ran, comma-separated, in the order you ran them, including this skill. That example is the shape, not a default list. If a `Plumbline-Skills:` line is already there, replace it. Do not add the line to commit messages, review comments, or a pull request you are only reviewing, and do not open a pull request just to add it.
