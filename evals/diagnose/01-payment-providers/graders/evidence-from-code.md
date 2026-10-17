---
type: llm
focus: last_message
---
PASS if the answer supports its diagnosis with at least two concrete examples from the given code of provider knowledge leaking outside a provider-specific module, for example:
- `refund` uses `payment.psp_reference` for Adyen but `external_id` elsewhere, while `webhooks.handle` looks Adyen payments up by `external_id` — an Adyen-only field in the shared `Payment` model that each module must know about;
- PayPal amounts converted to major units (`/ 100`) in both checkout and refunds;
- `provider_fee_cents` silently returning 0 for any provider it doesn't know (which matches the zero-fees incident);
- the `STATUS_MAP` keyed by provider-specific event names, and webhook signature/field extraction per provider;
- the provider list duplicated in the model's `choices`.

FAIL if the answer cites no concrete code, or cites only one example.
