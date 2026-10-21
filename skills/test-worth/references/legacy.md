# Untested code

Read this only on the Characterize route. Admission is still the record in [pillars.md](pillars.md). This file does not define the four criteria.

From Michael Feathers, *Working Effectively with Legacy Code*: code without tests is legacy code, whatever its age. A characterization test is written after the fact. It records what the code does today. It does not claim that behavior is what anyone wanted.

1. Find a seam that already exists: a place where one behavior can be varied without rewriting the module. The usual reason to need one is an unmanaged dependency (clock, network, database, filesystem, SDK).
2. Pin the observed output through that seam. Label the expected value as observed, not as specified.
3. If the observation looks like a bug, say so. Do not silently "correct" the expected value.
4. Do not add a seam that publishes private state. Do not copy the production algorithm into the test so the two can be compared. Both of those make resistance fail. The verdict is then `don't-write`, and the note names **deep-modules** or **information-hiding** rather than proposing the redesign.

The record uses verdict `characterize`. Resistance must hold. Production code does not change in this step. The change the user came to make happens after the test is green, as their edit or through **apply-fixes** if it came from a design finding.
