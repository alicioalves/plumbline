# What to write

Read this only on the Write route. Score every test you propose with the record in [pillars.md](pillars.md). This file does not define that record.

1. Name a behavior the caller of the production code can observe. Do not name a method, a branch, or a line to cover.
2. One behavior per test. Split only when the parts can fail for different caller-visible reasons. A single behavior's multiple assertions stay in that one test; see assertion-roulette in [smells.md](smells.md).
3. Prefer an assertion on an output the caller receives. Then public state the caller can read. Then a communication, and only when that communication is the behavior.

A proposed test of a private method, a getter, or a constructor with no behavior is `don't-write`. Leave it in the answer so the user sees the rejection. Do not add it to the suite.

Show the records before editing. The editing rules are in `SKILL.md`.
