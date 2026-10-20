---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that at least three of `ErrOutOfRange`, `ErrInvertedRange`, `ErrEmptyRange` and `ErrFadeTooLong` are returned for conditions that every caller neutralises in the same trivial way (clamping to the clip's duration, swapping the endpoints, treating an empty range as "nothing to do", fading the whole clip when the fade is longer than it), AND recommends changing the `clip` package's specification so these are no longer errors: `Window` / `Cut` clamp times to `[0, DurationMs()]` and accept the endpoints in either order, cutting an empty range is a successful no-op, and `FadeOut` fades at most the whole clip, so the tools lose their `errors.Is` handling entirely. The framing must be that the error cases themselves are unnecessary interface surface (defining errors out of existence, reducing the number of exceptional cases, or equivalent), not only that the callers' handling should be shared.

FAIL if these error values are not addressed, or if the only fix is a helper / wrapper around the existing calls, better error messages, or wrapping errors with `%w`, while `Clip` keeps returning the same errors.
