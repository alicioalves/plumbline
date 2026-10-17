---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that the crate makes every caller handle SMS mechanics that only the gateway crate understands — choosing the encoding (`is_gsm7` then picking `Encoding`), splitting text into parts with the right per-part limits (153/67 for multi-part vs 160/70 for single), assigning part numbers, totals and a shared reference, and producing E.164 numbers — AND connects the reported failures to callers getting that wrong (orders splits multi-part messages at 160/70 instead of 153/67 and builds numbers by stripping leading zeros without a country code; auth hard-codes `Gsm7` for a body containing a non-GSM-7 dash), AND frames it as complexity pushed up to callers that the module should absorb (the module knows these rules and could apply them once; every caller re-implements them; better docs would not remove the burden), AND recommends a higher-level interface such as `send(to, text)` that picks the encoding, segments and numbers parts internally, with phone normalization/validation owned by the crate (e.g. a `PhoneNumber` type parsed with a default region) and `Segment` / `Encoding` / `send_segment` made internal or demoted to an advanced path.

FAIL if the answer mainly recommends better documentation, examples or a lint, only fixes the individual bugs in the callers (correcting the limits, changing auth to `Ucs2`), or offers a shared helper for callers while keeping segmentation and encoding as the caller's job.
