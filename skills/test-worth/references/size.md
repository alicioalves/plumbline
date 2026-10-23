# Size bands

This file only scores the feedback criterion in [pillars.md](pillars.md). It never emits a verdict.

Size is which resources a test uses, not how much production code it reaches and not the word "unit". From *Software Engineering at Google*, chapter 11: some of the limits are enforced by the test infrastructure, and scope — how much code is validated — is a separate axis.

- **small** — one process. No blocking I/O, no network, no disk, no sleep.
- **medium** — may use more than one process. Stays on localhost. No external system.
- **large** — may leave the machine and talk to an external system.

A small test can still lock the implementation. A large test can still be the only protection for a behavior. Say the size in the record, then score feedback in `pillars.md`. Do not rename a test "unit" or "integration" in the record.
