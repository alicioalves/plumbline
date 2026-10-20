---
type: llm
focus: last_message
weight: 1
---
PASS if the answer gives a clear verdict that the current split is drawn in the wrong place, and either (a) merges the two packages, or (b) moves the boundary so that everything about the queue's state and invariants lives on one side behind a narrow interface (e.g. `Record`, `NextBatch(n)`, `Ack(seqs)`, `Fail(seqs)`, `Pending()`), leaving the other side with only transport / scheduling, AND justifies it from this code: both packages currently share knowledge of the queue's internals — the exported `Ops` slice and its ordering, the `InFlight` and `Attempts` fields, the rule that in-flight ops must not be collapsed by `Record`, the retry limit `maxAttempts` (which also defines what "pending" means), and the exported `Lock`/`Unlock` that the syncer must call around direct slice manipulation — so a change to any of these rules forces edits on both sides, which is the user's symptom.

FAIL if the answer endorses the current split with only cosmetic changes (e.g. adding getters, moving constants, renaming), argues purely from package size or "single responsibility" without pointing to the shared queue knowledge, or splits the code further without saying which side owns the queue invariants.
