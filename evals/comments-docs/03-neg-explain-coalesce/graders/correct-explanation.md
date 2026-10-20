---
type: llm
focus: last_message
---
PASS if the answer explains correctly that `coalesce`: drops empty (or inverted) ranges, sorts by start, and merges a range into the previous one when it overlaps, touches, or starts no more than `gap` bytes after the previous range's end, so the merged range also covers the gap bytes in between (over-reading to save requests); the output is sorted and non-overlapping. It must also give the correct result for the example: `[0..20, 40..50]` (5..8 is absorbed into 0..10, 12..20 is merged because 12 <= 10 + 4, and 40..50 stays separate because 40 > 20 + 4). FAIL if the example result is wrong or missing, or if the explanation of `gap` is wrong (e.g. says ranges must overlap, or that `gap` limits the merged range's size).
