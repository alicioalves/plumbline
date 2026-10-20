---
name: code-evolution
description: "Use when the user asks for a PR or diff review (\"PR review please\", \"anything to change before this goes in?\", \"can you look at this diff?\"), or about recently changed files, to judge whether each change is designed-in or bolted-on: special cases, flags and copies added instead of extending the design. Reads the change with git when it can. Not for a design-smell scan of code that isn't a change (use red-flags) or the overall investment balance of a codebase (use strategic-mindset)."
argument-hint: "[file, module, or PR]"
allowed-tools: Read, Grep, Bash(git log:*), Bash(git diff:*), Bash(git show:*)
---

# Code Evolution Review Lens

When invoked with $ARGUMENTS, focus the analysis on the specified file, module, or pull request. Read the target code first, then apply the checks below.

Evaluate whether code modifications maintain or degrade design quality.

## When to Apply

- Reviewing a PR that modifies existing code
- After adding a feature to an existing system
- When code has accumulated patches and feels degraded
- When deciding whether to refactor during a feature change

## Core Principles

### Technical Debt

Technical debt doesn't come from catastrophic decisions. It comes from hundreds of small, reasonable shortcuts that compound silently until the codebase starts fighting back. Calling it "debt" at all is generous because the financial kind gets repaid.

#### During Modifications

- Debt in the area being modified → fix it now (context is fresh, fix is cheapest)
- Debt elsewhere affecting the modification → document it, fix if feasible
- Never add to the pile. Each modification should reduce debt, not increase it

#### Refactoring

Refactoring is not a special event. It is the normal expression of strategic programming applied to existing code. Continuous small improvements, not periodic large refactors.

### The "Designed This Way" Standard

> "Ideally, when you have finished with each change, the system will have the structure it would have had if you had designed it from the start with that change in mind." — John Ousterhout, _A Philosophy of Software Design_

The design of a mature system is determined more by changes made during its evolution than by any initial conception. Every modifier either continues toward the original trajectory or bends away.

#### Three-Question Test

1. If someone were designing this system from scratch knowing this requirement, what would it look like?
2. Does the modified code match that ideal, or is the change visibly patched on?
3. If not, what's the minimum restructuring to close the gap?

#### The Middle Path

When the ideal refactoring would require touching far more of the codebase than the current task budget allows, the question isn't "can I afford the full redesign?" It's "what's the best I can do within this change's scope?" That question often surfaces an approach nearly as clean as the ideal, achievable within the current diff, that the smallest-change mindset would never find because it anchors on the current code.

### The "Smallest Possible Change" Trap

There is no neutral gear. Every change either improves the design or degrades it.

Each minimal change typically introduces a special case, a dependency, or a conditional that doesn't belong. Once, negligible. Across hundreds of modifications over years, this is how well-designed systems become legacy nightmares.

### Repetition Audit

After a modification, ask yourself:

- Does the same logic now exist in multiple places?
- Was similar code duplicated instead of abstracted?
- Would a similar change require edits in multiple locations?

Repeated code is a red flag that the right abstraction hasn't been found yet.

#### Two Strategies

1. **Extract and call**: Works best when the method forms a deep abstraction. If the snippet is two lines but requires five parameters, extraction may add more complexity than it removes.
2. **Restructure so the code runs once**: Sometimes better because it eliminates duplication entirely.

_When not to extract_: Code that looks identical can represent two independent decisions that happen to be expressed the same way. Merging them creates artificial coupling.

### Comment Maintenance

Stale comments are worse than missing comments because they actively mislead. Once readers discover comments can't be trusted, they stop reading them entirely.

Five maintenance rules:

1. **Keep comments near the code they describe**: proximity is a maintenance mechanism

2. **Put comments in code, not commit logs**: developers navigate code spatially, not chronologically

3. **Document each decision exactly once**: duplicated documentation drifts invisibly

4. **Check the diffs before committing**: verify documentation still matches behavior

5. **Prefer higher-level comments**: abstract comments that describe _what_ and _why_ survive code changes better than detailed _how_ comments. As Ousterhout writes, "the farther a comment is from the code it describes, the more abstract it should be"

## Review Process

Before step 1:

- **Get the change**: if the target is a branch or PR in a git repository, read it with `git diff <base>...HEAD` (usually `main...HEAD`) and `git log --oneline <base>..HEAD` for the commit story, then open full files with `git show HEAD:<path>` only where the diff lacks context. Outside a git repo, review the diff or files you were given.
- **Check remembered findings**: if the project has `.plumbline/findings.md`, read it. Call out a change that reintroduces a `fixed` finding (a regression) or adds to an `open` one, and credit a change that resolves one. Don't edit the file from here; that happens when the user runs **red-flags** or **apply-fixes**.
1. **Apply the "designed this way" test**: Does the modification look native or bolted-on?
2. **Check for incremental complexity**: Did the change add special cases, dependencies, parameters, or flags?
3. **Run repetition audit**: Did the change introduce or perpetuate duplication?
4. **Verify comment maintenance**: Are all affected comments updated?
5. **Assess debt trajectory**: Is the modification reducing or increasing technical debt?
6. **Recommend**: Specific improvements to make the change feel designed-in

Red flag signals for code evolution are cataloged in **red-flags** (Repetition, Tactical Momentum).

## Pull request signature

If this session opens a pull request, or updates the body of one it opened, end that body with a single line of the form `Plumbline-Skills: red-flags, deep-modules`. List the directory name of each Plumbline skill whose checks you actually ran, comma-separated, in the order you ran them, including this skill. That example is the shape, not a default list. If a `Plumbline-Skills:` line is already there, replace it. Do not add the line to commit messages, review comments, or a pull request you are only reviewing, and do not open a pull request just to add it.
