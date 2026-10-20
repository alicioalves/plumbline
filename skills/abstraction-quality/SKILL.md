---
name: abstraction-quality
description: "Use when layers feel redundant or mirror each other (\"the service just mirrors the repository\", \"this wrapper adds nothing\"), a decorator or adapter re-exposes what it wraps, or an abstraction leaks what it was meant to hide (callers must know when data is really saved, flushed or retried). Evaluates whether each layer offers a genuinely different way of thinking about the problem. Not for one module's interface-to-implementation ratio (use deep-modules) or knowledge leaking across unrelated modules (use information-hiding)."
argument-hint: "[file or module path]"
allowed-tools: Read, Grep
---

# Abstraction Quality Review Lens

When invoked with $ARGUMENTS, focus the analysis on the specified file or module. Read the target code first, then apply the checks below.

Evaluate whether abstractions are genuine (hiding complexity) or false (adding layers without reducing what callers must know).

## When to Apply

- Reviewing class hierarchies or layered architectures
- When an abstraction feels like it adds complexity rather than reducing it
- When decorator or wrapper patterns are used
- When two layers seem to operate at the same level of abstraction

## Core Principles

### Genuine vs. False Abstraction Test

**Can callers forget what's underneath?** If yes, it's genuine. If callers must peek through to use it correctly, it's false.

#### Two Ways Abstractions Fail

- **Including unimportant details**: The interface leaks implementation concerns. Shows up as wide interfaces, excessive parameters. More common, at least visible.
- **Omitting important details**: The interface hides something callers need. **More dangerous because it signals nothing.** The abstraction appears clean, inviting trust it doesn't deserve.

A file system can safely hide which disk blocks store data. It cannot hide flush rules for durable storage. Databases depend on that guarantee.

### Different Layer, Different Abstraction

**Each layer should provide a fundamentally different way of thinking about the problem.** If two adjacent layers have similar methods, similar parameters, similar concepts, the layering adds cost without value.

Check: compare the interface of each layer. Are they at different conceptual levels? Or is one just a thin rephrasing of the other?

### Decorator Pattern Trap

**Decorators are structurally committed to shallowness.** A decorator that adds one behavior to a class with twenty methods has nineteen pass-throughs and one meaningful method.

For the full decorator-alternatives checklist, see deep-modules' "Decorator Alternatives" section.

Ask whether the new functionality really needs to wrap the existing functionality. If not, implement it independently.

### Resolving False Abstractions

See deep-modules' "Pass-Through Method Audit" fixes (Expose, Redistribute, Merge) for the full remedy taxonomy.

## Review Process

1. **Map layers**: Identify the abstraction layers under review
2. **Compare adjacent layers**: Do they provide different mental models?
3. **Test each abstraction**: Can callers forget what's underneath?
4. **Audit decorators/wrappers**: Adding depth or just adding a layer?
5. **Check pass-throughs**: Any methods or variables that just forward without contributing? (See **deep-modules** for pass-through audits, interface-vs-implementation checks, and when signature duplication is legitimate.)
6. **Resolve**: Redistribute, merge, or expose

## Relationship to Other Lenses

This skill asks "is the abstraction genuine?": does each layer provide a different way of thinking? **deep-modules** asks the follow-up: "is the module deep enough?": does the interface justify what's behind it? A layer can provide a genuinely different abstraction and still be shallow. Use this skill first to evaluate layer structure, then **deep-modules** to evaluate depth within each layer.

## Pull request signature

If this session opens a pull request, or updates the body of one it opened, end that body with a single line of the form `Plumbline-Skills: red-flags, deep-modules`. List the directory name of each Plumbline skill whose checks you actually ran, comma-separated, in the order you ran them, including this skill. That example is the shape, not a default list. If a `Plumbline-Skills:` line is already there, replace it. Do not add the line to commit messages, review comments, or a pull request you are only reviewing, and do not open a pull request just to add it.
