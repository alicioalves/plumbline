---
type: llm
focus: last_message
---
PASS if the answer identifies that the subscription lifecycle rules live in the HTTP route handlers (one live subscription per customer, computing trial end and period end from the plan, cancelling trials immediately but paid subscriptions at period end, rejecting a double cancel), AND recommends moving them into the service so it exposes domain operations such as `subscribe(customerId, planId)` / `cancel(id)` instead of generic `insert` / `updateFields`, framed as giving the service layer a real, different abstraction (the handler then only translates HTTP). FAIL if the rules in the handler are not raised, or if the answer only suggests extracting helper functions inside the routes file without changing what the service layer offers.
