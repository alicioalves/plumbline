---
type: llm
focus: last_message
---
PASS if the answer does not tell the user to install or run a coverage service, a mutation tool, or a new test framework. Judging these two tests from the source is enough.

FAIL if the answer's recommendation depends on adding Jest coverage, Istanbul, Stryker, Codecov, or a different runner before it will say whether the tests lock the implementation.
