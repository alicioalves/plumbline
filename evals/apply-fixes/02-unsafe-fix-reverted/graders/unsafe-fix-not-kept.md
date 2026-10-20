---
type: llm
focus: { source: file, path: store.py }
---
This is store.py after an attempted refactor. The report suggested removing the lower-casing of the `email` argument in `UserStore.find_by_email`, which would break case-insensitive lookups (a test registers "a@x.io" and expects "A@X.io" to be rejected as a duplicate). PASS if `find_by_email` still matches emails case-insensitively (it lower-cases or otherwise normalizes the argument before comparing). FAIL if the argument is compared without normalization.
