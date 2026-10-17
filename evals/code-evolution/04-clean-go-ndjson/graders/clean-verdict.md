---
type: llm
focus: last_message
---
Step 1. Find the answer's overall verdict on the change (usually near the top: "designed-in", "fits the existing design", "looks native", "good to merge", "no structural problems", or the opposite, e.g. "bolted-on").

Step 2. Check whether the answer recommends RESTRUCTURING. Restructuring means ONLY one of these:
- splitting the file/module/type into several, or merging it with something else;
- replacing the core approach or algorithm (e.g. "drop the format registry", "rewrite this as a class hierarchy");
- telling the user to replace the code with a library instead of keeping it.

These are NOT restructuring, however they are labelled: adding a method, option, or parameter to the existing type/function; input validation; edge-case or correctness fixes; comments, docstrings, or naming; mentioning that a library exists as background.

PASS if the verdict in Step 1 is positive (the change is designed-in / fits the existing design / fine to merge) AND Step 2 finds no restructuring recommendation. FAIL otherwise. Quote the verdict sentence and any restructuring recommendation in your reasoning.
