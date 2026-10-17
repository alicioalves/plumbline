---
type: llm
focus: last_message
---
PASS if the answer identifies that each channel's behaviour is split across several `switch n.Channel` statements (`Validate`, `render`, `Send`, `RetryDelay`, plus the constant list), so adding or changing a channel (e.g. Slack, WhatsApp) requires coordinated edits in four or more places — and that `RetryDelay`'s `default` branch would silently give a new channel the email retry policy, so a missed edit produces no error — AND frames it as a design problem (change amplification, channel knowledge scattered by operation rather than grouped by channel, or equivalent), AND recommends grouping each channel's knowledge in one place (e.g. a channel interface/type per channel that owns validation, rendering, sending, retry policy and its recipient).

FAIL if not raised, or if the switches are only mentioned as style/verbosity ("use a map", "switches are long") without the point that one channel change touches many places.
