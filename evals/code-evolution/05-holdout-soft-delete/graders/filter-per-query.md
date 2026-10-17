---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that the PR implements "trashed notes are hidden" by hand-adding `trashed_at IS NULL` to each existing query one by one, and that `search` was missed (trashed notes still show up in search results), AND frames this as a bolted-on rather than designed-in change: visibility of trashed notes is a rule that now has to be remembered in every current and future query, so the next query someone writes will silently include trashed notes (repetition / scattered rule / change that does not fit the existing structure, or equivalent), AND recommends making the rule live in one place so queries get it by default, e.g. a single base query or helper that every read goes through, a `live_notes` view, a repository-level scope, or an explicit opt-in only for the trash/restore paths.

FAIL if the missing filter in `search` is not raised, or is reported only as "add `AND n.trashed_at IS NULL` to `search` too" with no point about the filter being duplicated across queries and needing a single owner.
