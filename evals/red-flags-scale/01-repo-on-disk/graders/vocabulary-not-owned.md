---
type: llm
focus: last_message
---
PASS if the answer identifies that the CLI, HTTP and SDK packages each re-implement knowledge the core package should own — the channel-name parsing and naming (`parseChannel` / `channelName` or equivalent string tables), the error-code mapping, and/or the defaults merge for send options — AND frames the fix as the core exposing that vocabulary once (for example a `parseChannel`/`channelName` and an error `code` exported from core, and a single `resolveOptions` with the defaults), so adding a channel or error no longer means editing every adapter. FAIL if the duplication across adapters is missed, or the only fix is a shared helper among the adapters with no point about the core owning it.
