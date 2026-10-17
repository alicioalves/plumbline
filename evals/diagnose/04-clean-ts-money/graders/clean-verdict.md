---
type: llm
focus: last_message
---
Step 1. Find the answer's overall conclusion about whether the code has a structural design problem (e.g. "there's no structural problem here", "this is well designed", "the shape is good", or the opposite: a named problem such as a shallow module, information leakage, or a wrong abstraction).

Step 2. Check whether the answer recommends RESTRUCTURING. Restructuring means ONLY one of these:
- splitting the file/module/type into several, or merging it with something else;
- replacing the core approach or algorithm (e.g. "don't store minor units", "rewrite this as a class hierarchy");
- telling the user to replace the code with a library instead of keeping it.

These are NOT restructuring, however they are labelled: adding a method, option, or parameter to the existing type/function; input validation; edge-case or correctness fixes; comments, docstrings, or naming; mentioning that a library exists as background.

PASS if Step 1 concludes there is no structural problem AND Step 2 finds no restructuring recommendation. Routing to or applying another lens (for example complexity-recognition) is fine as long as the answer's conclusion is still that the code is sound. FAIL if the answer routes to a lens and reports a structural problem the code does not have, or recommends restructuring. Quote the conclusion sentence and any restructuring recommendation in your reasoning.
