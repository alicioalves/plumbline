---
type: llm
focus: last_message
weight: 1
---
PASS if the answer agrees that most comments only restate the code or the name ("Digest preferences.", "The hour.", "The time zone.", "@param now the now", "set the hour", "return the date", "the min gap") and should be removed or replaced, AND says what the doc comments should contain instead because callers cannot get it from the signatures, with at least two concrete items such as: `hour` is 0–23 in the user's local time, not UTC; `timeZone` is an IANA zone name; weekly digests always go out on Mondays; the returned `Date` is an absolute instant (to be stored or compared in UTC); when `lastSentAt` is null the first digest is the next slot, never immediately; a digest sent less than 20 hours (daily) / 6 days (weekly) before the next slot pushes it one more period, to avoid double sends (e.g. after a time zone change); what happens when the hour does not exist on a DST-change day; what `MIN_GAP_HOURS` is for. The framing must be about comments describing what callers need and what isn't obvious from the code (interface contract, the reason behind the gap rule) rather than narrating each line.

FAIL if the restating comments are not raised, or if the answer only says to "add more detail" or "document the parameters better" without naming at least two pieces of missing behaviour.
