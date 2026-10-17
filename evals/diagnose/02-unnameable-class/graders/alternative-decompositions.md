---
type: llm
focus: last_message
---
PASS if the answer proposes splitting the class into smaller pieces that each have an obvious, precise name (e.g. a token/auth session, a current-user/profile store, a feature-flag evaluator, an analytics wrapper, a display-name formatter, a last-workspace preference), AND weighs at least two different ways to draw those lines before recommending one — for example comparing a fine-grained split against a coarser one, or discussing where a contested piece belongs (do flags belong with the profile? does `trackPage` belong with analytics or with the session? should display-name formatting be a pure function on `UserProfile`?) — with a reason for the choice (what changes together, who depends on it, which pieces need the token).

FAIL if no split is proposed, or if exactly one split is presented with no alternative considered and no reasoning about where the lines go.
