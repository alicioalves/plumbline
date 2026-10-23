# Canon TDD

Read this only on the Drive route, and only when the user asked to build new behavior test-first. This is a writing procedure. It is not the definition of a test worth keeping. Admission is still the record in [pillars.md](pillars.md).

From Kent Beck, [Canon TDD](https://newsletter.kentbeck.com/p/canon-tdd):

1. List the scenarios. Do not turn them all into tests.
2. Pick one. Write one failing test. The interface is decided here.
3. Watch it fail for the reason you expect. A failure for a typo or a missing import is not that reason.
4. Make it pass with the smallest production change. Do not refactor in this step. Implementation decisions wait.
5. Refactor only while the suite is green. Stop when the next scenario is the harder problem.

Score the draft with the record before the first production edit. After it is green, do not start the next scenario unless the record is `keep`; otherwise rewrite or delete that test first. A test that locks the implementation is not "done" because it went red and then green.

Test-and-commit-or-revert is not this loop. Do not adopt it from this file.
