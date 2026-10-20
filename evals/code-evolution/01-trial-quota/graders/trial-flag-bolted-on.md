---
type: llm
focus: last_message
---
PASS if the answer identifies the new `isTrial` parameter on `limitFor`/`checkQuota`, which every caller must compute for itself from `account.trialEndsAt` (with differing expressions in `projects.ts` and `uploads.ts`), as a bolted-on special case rather than a designed-in change: trial status is already on the `Account`, so the quota module should determine it internally (or model trial limits as data, e.g. an effective-limits function or trial entries alongside `PLAN_LIMITS`) and the call sites should not have changed at all. The answer must note the consequence that callers who don't pass the flag — the seat-invite handler and API gateway middleware not touched by this PR — silently give trial and even expired-trial accounts full plan limits.

FAIL if the flag is not discussed as a design problem, or if the only fix offered is to add `isTrial` to the remaining callers.
