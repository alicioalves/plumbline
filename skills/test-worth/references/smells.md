# Smell catalog

This is the whole catalog. A smell accuses one criterion from [pillars.md](pillars.md). It does not say keep, rewrite, or delete. A smell that is not listed here is not reported. Adding a smell means adding a section to this file and nothing else.

The names follow Gerard Meszaros, *xUnit Test Patterns*. The short list is a choice: the book is a catalog of more than a hundred patterns, and an agent that tries to apply all of them produces a review instead of a verdict.

## overspecified

Accuses resistance.

The test goes red when caller-visible behavior stays the same. Assertions on call order, private fields, incidental structure of a returned object, or the wording of an internal error.

Not this: an assertion on a value the caller actually receives, including an error the caller is expected to handle.

## mockery

Accuses resistance.

An in-process collaborator is replaced, or the test asserts that a call happened when that call is not the feature.

Not this: a double at an existing edge for a clock, the network, a database, the filesystem, or a third-party SDK. The rule for which doubles are justified lives in `pillars.md`. This smell does not restate it.

## slow-test

Accuses feedback.

Sleep, network, disk, or a shared service for a behavior a small test could protect.

Not this: the only test that protects a behavior, where the resources are required to observe it. Size bands live in [size.md](size.md).

## obscure-test

Accuses maintainability.

The behavior is not visible in the test. The expected value arrives from a file, a helper, or a fixture the reader has to open. The test name hides the scenario.

Not this: a named input sitting next to the assertion.

## conditional-logic

Accuses protection.

An `if`, a loop, or a `try` decides what the test means. A reader cannot say which behavior failed.

Not this: a loop that builds one input table and asserts one behavior per row, with the row named in the failure.

## assertion-roulette

Accuses maintainability.

Several unrelated behaviors in one test, so a failure names no behavior.

Not this: several assertions that describe one behavior (the response status and the body of that same response).

## erratic-test

Accuses protection.

The test depends on order, on a shared mutable fixture, on the clock, or on unseeded randomness. A red run might be the test.

Not this: a failure that reproduces from the inputs in the test itself.
