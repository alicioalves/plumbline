---
type: llm
focus: last_message
---
PASS if the answer identifies at least one name used for two different concepts, and frames it as a consistency problem (the same name hiding different meanings, so readers carry the wrong model from one place to the other):
- `ttl` is a duration in seconds in `Config.TTL` but an absolute Unix expiry timestamp in `entry.ttl` (fix: e.g. `expiresAt`/`expiresUnix`), or
- `id` is a session ID in `Get`/`Handle` but a user ID in `ForUser`, while `Info.ID` is the session ID and `Info.Uid` the user ID (fix: e.g. `sessionID` / `userID` consistently).
FAIL if neither split is raised, or if `ttl` or `id` is mentioned only as "could be more descriptive" without pointing out that the same name means two different things.
