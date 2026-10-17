---
type: llm
focus: last_message
---
PASS if the answer identifies that `search` has parameters that each exist for exactly one caller (`for_admin_panel`, `mobile_client`, `include_line_items_for_export`) and treats this as a generality problem: caller-specific policy (admin sees deleted orders and emails, mobile page cap, export line items) is encoded in a shared lower-level module, widening its interface and coupling it to its callers. The recommended fix must push that specialization out to the callers or replace the flags with general capabilities (e.g. a general `include_deleted` option or filter field, the mobile endpoint capping its own page size, a separate `line_items_for(order_ids)` or similar, the admin layer fetching emails), at least for two of the three flags. FAIL if the flags are not raised, or if the only suggestion is to group them into an options object/enum or rename them, which keeps the caller-specific knowledge inside `search`.
