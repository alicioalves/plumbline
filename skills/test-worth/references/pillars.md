# The acceptance rule

This file is the only place the acceptance rule is defined. Other files point here. They do not restate it.

Adapted from Vladimir Khorikov, *Unit Testing Principles, Practices, and Patterns*. The goal of a test suite is sustainable growth of the project. A better design is a side effect, not the goal. A test that is slow, that breaks on refactors, or that raises false alarms costs more than it protects, and a suite of those tests leads to stagnation. Keeping a test is a cost-benefit decision.

This file is not a substitute for the book. The project is not affiliated with or endorsed by Vladimir Khorikov.

## The four criteria

A test earns `keep` only when all four hold. Name each one in the record with the evidence from the code, not a label alone.

- **Protection against regressions.** The regression a caller of the production code would notice: money, permissions, persistence, a protocol, or a real branch in behavior. `pays` means that regression fails this test. `weak` means the test covers a getter, a constructor, a log line, or a behavior another resistant test already protects. `none` means the test cannot fail when that behavior breaks: a tautology, an assertion on a mock the test just configured, or no assertion.
- **Resistance to refactoring.** `holds` means a refactor that preserves caller-visible behavior leaves the test green. `locks` means the test goes red because it asserts call order, private state, incidental fields, or the text of an internal error. **`locks` vetoes `keep`.** No amount of code executed underneath repairs it. The verdict is `rewrite` when the behavior is worth protecting and `delete` when it is not.
- **Fast feedback.** `fast` or `slow`, scored with the bands in [size.md](size.md). `slow` is not automatically `delete`. Rewrite toward a smaller test of the same behavior, or `keep` only when this test is the only `pays` coverage of that behavior and resistance `holds`.
- **Maintainability.** `holds` or `costly`. `costly` means a reader cannot see the behavior in the test, or the test is expensive to change for reasons other than the production behavior. Several unrelated behaviors in one test are `costly` and force `rewrite` by splitting.

The other three criteria can be traded against each other. Resistance cannot.

## Test doubles

A double is justified only when it replaces a dependency that is shared, slow, or not owned by the process — a clock, the network, a database, the filesystem, a third-party SDK — and only at an edge that already exists. Collaborators in the same process stay real. An assertion that a collaborator was called is allowed only when that interaction is the caller-visible behavior (the message was handed to the mail port the caller depends on). Anything else is resistance `locks`.

## The record

Emit one record per existing test, and one per test you propose to write. Do not add fields.

```text
behavior: <one sentence a caller can observe>
size: <small | medium | large>
protection: pays | weak | none — <which regression, or why none>
resistance: holds | locks — <which refactor would turn it red>
feedback: fast | slow — <which resources>
maintainability: holds | costly — <what is hard to read or change>
smell: <a slug from smells.md, or none>
verdict: keep | rewrite | delete | don't-write | characterize
```

## Verdicts

- `keep` — all four hold.
- `rewrite` — the behavior is worth protecting and this test does not say it. Includes a `locks` test of a real behavior, a test with more than one behavior, and a `slow` test that can shrink.
- `delete` — protection is `none`, or the behavior is `weak` and the test `locks` or is `costly`.
- `don't-write` — the proposed test would be `delete` or `rewrite` on arrival. A test of a private method or a getter is `don't-write`. Say so and do not add it.
- `characterize` — there is no independent oracle. The test records observed output. Protection is whatever the observation covers. Resistance must `holds`. Used only on the Characterize route.

`pillars.md` does not switch on smell slugs. A smell accuses a criterion. The verdict is decided here.
