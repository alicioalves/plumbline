---
type: llm
focus: last_message
---
PASS if the answer gives BOTH:
1. An overall verdict on how the code was built: it reflects shortcut-driven / tactical work whose cost compounds — the answer projects forward (e.g. what the next customer formats or the next fix will cost if the pattern continues) rather than only judging whether it currently works; and
2. A concrete, scoped investment recommendation: what to change first, a rough size or effort (hours/days/points or "one PR"), and when to do it — e.g. before or as part of the next customer format request — rather than an open-ended "rewrite it" or "add to the backlog".

FAIL if the answer only lists issues without a verdict on the trajectory, if it calls the code fine as-is, or if the recommendation is vague ("refactor when you have time", "consider cleaning this up") with no concrete first step and timing.
