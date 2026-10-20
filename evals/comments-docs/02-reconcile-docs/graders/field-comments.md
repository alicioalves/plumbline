---
type: llm
focus: last_message
---
PASS if the answer identifies that the `Spec` field comments only restate the field names ("Replicas is the number of replicas", "DrainTimeout is the drain timeout") and omit what is not obvious from the type and name, AND gives at least two concrete examples of the missing information, such as: `DrainTimeout`'s unit (seconds, only discoverable inside `drain`), what `MaxSurge` means and that 0 is treated as 1, what `Replicas == 1` triggers (drain-before-start for singletons), or which `Image` format is expected. Suggesting `time.Duration` for `DrainTimeout` counts as one example if tied to the missing unit. FAIL if the restating field comments are not raised, or if the answer only says they are "too terse" without naming any missing information.
