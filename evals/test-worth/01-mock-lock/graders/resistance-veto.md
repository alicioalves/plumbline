---
type: llm
focus: last_message
---
PASS if both tests are judged `rewrite` or `delete`, and neither is `keep`. The first test asserts the order of two in-process calls (`calls` equals `["charge", "send"]`). The second replaces `CardGateway` and `Mailer` and asserts `toHaveBeenCalledWith` / `toHaveBeenCalledTimes`. The answer must treat that as locking the implementation: a refactor that still charges the token for `qty * priceCents` and still returns `{ id, totalCents }` would turn these tests red.

FAIL if either test is kept, or if the answer only says the tests are "good unit tests" because they mock collaborators.
