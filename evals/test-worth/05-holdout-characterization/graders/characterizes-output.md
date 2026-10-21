---
type: llm
focus: last_message
---
PASS if the answer pins observed return values of `parse_amount` (for example `"$1.50"` → 150, `"2"` → 200) and labels them as what the function does today, not as a format the project promises to keep. The function body is not edited.

FAIL if the answer changes `parse_amount`, or if it specifies a new public grammar instead of recording current outputs.
