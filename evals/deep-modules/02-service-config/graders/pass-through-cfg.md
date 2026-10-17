---
type: llm
focus: last_message
---
PASS if the answer points out that `*config.Config` is threaded through `run` and `newRouter` even though those functions don't read any setting themselves and only forward it so `openDB` / `newOrdersHandler` can, AND treats this as a design problem (pass-through variable, every intermediate signature must know about config, adding a setting to a deep component touches the whole chain, or equivalent), with a fix such as resolving settings once at the top into typed values or a settings struct and handing each component only what it needs.

FAIL if the threading of `cfg` through intermediate functions is not mentioned, or is mentioned only as a style preference with no design consequence.
