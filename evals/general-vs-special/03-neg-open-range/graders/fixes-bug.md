---
type: llm
focus: last_message
---
PASS if the answer shows a corrected `ParseRange` in which the open-ended case (`bytes=a-`) returns `end = size - 1` (so `bytes=500-` on a 1000-byte file yields start 500, end 999), while the suffix case, the explicit `a-b` case, the error returns and the `capForMobile` clamp keep their existing behavior. FAIL if the open-ended end is still `size`, if another case is broken, or if the fix is only described in prose without code.
