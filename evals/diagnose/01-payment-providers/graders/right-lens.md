---
type: llm
focus: last_message
---
PASS if the answer diagnoses the cause as knowledge about each provider being spread across many modules rather than owned by one — every file has its own `if provider == ...` chain and carries provider-specific details — i.e. the provider details are not hidden behind a single module (information leakage / missing information hiding / no provider abstraction, or equivalent), AND explains why that produces both symptoms the user reported (the six-file edit and the missed edits, since nothing forces a new provider to be handled everywhere), AND recommends the corresponding remedy: put each provider's knowledge (checkout, refund, webhook parsing/status mapping, fees, identifiers) behind one provider interface/adapter so adding Mollie means writing one new module and registering it.

Accept any wording ("encapsulate each provider", "provider adapter/gateway", "strategy per provider") as long as the explanation is about concentrating provider knowledge in one place. FAIL if the answer is a generic list of code-review issues, or recommends only local fixes (e.g. a default branch that raises, a checklist for adding providers, more tests) without the concentrate-provider-knowledge diagnosis.
