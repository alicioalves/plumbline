---
type: llm
focus: last_message
---
PASS if the answer explains `coalesceWindows` accurately, covering all of:
- it copies and sorts the windows by `start` (ties by `end`) without mutating the caller's array or objects;
- it walks the sorted list and merges a window into the previous output window when its `start` is at or before the previous window's `end + gapMs` — i.e. overlapping, touching, or separated by a gap of at most `gapMs` — otherwise it starts a new output window;
- `gapMs` is a tolerance that lets windows separated by a short gap (15 minutes in the calendar call) be treated as one; with the default 0 only overlapping or touching windows merge;
- on a merge, `end` becomes the later of the two ends, and the labels are joined with `+`, skipping a label already present among the `+`-separated parts.

FAIL if any of these is missing or stated incorrectly (e.g. claims it mutates the input, that `gapMs` shrinks or pads the windows, or that labels are always concatenated).
