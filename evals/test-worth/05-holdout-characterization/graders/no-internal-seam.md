---
type: llm
focus: last_message
---
PASS if the test calls `parse_amount` and does not assert on `_AMOUNT`, the match groups, or any new accessor added so the test can see the regex. Refusing to publish that private pattern is part of passing.

FAIL if the answer exports `_AMOUNT`, adds a method that returns the compiled pattern, or asserts the regex text.
