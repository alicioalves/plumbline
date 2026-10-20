---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that "active" means two different things in this module — `Member.active` / `is_active` / `deactivate` mean "still a member, not removed", while the `active` parameter of `get_members` (default `True`) and `notify_active` mean "seen in the last five minutes / currently online" — AND ties the reported bugs to readers carrying one meaning into the other (e.g. `billable_seats` and `team_page` call `get_members(org_id)` expecting current members but get only online ones, so seats are undercounted and the team page lists only people online; announcements via `notify_active` reach only online members; `seat_count` has to pass `active=False` and then re-filter on `m.active`), AND frames it as a naming / obviousness problem (one name for two concepts, inconsistent vocabulary, names that create the wrong mental model, or equivalent), AND proposes distinct, precise names and/or separate functions, e.g. `removed` / `is_current_member` for membership and `online` / `recently_seen` for presence, with `get_members` split into something like `current_members(org_id)` and `online_members(org_id)`. Noting that the same id is also called `org`, `tenant_id`, `account_id` and `org_id` is a plus but not required.

FAIL if the double meaning of `active` is not raised, or if the answer only suggests adding comments/docstrings or a more descriptive name for one of the two uses without pointing out that the same word names two different concepts.
