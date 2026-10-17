---
type: llm
focus: last_message
---
PASS if the answer correctly explains all three of:
1. `Ok(None)` means the buffer does not yet hold a complete frame (fewer than the 10 header bytes, or the header is present but the payload is incomplete); it is not an error, and `next_frame` responds by reading more bytes from the socket and trying again.
2. `Err(..)` means the bytes are malformed and can't become a frame (wrong magic, unknown kind byte, or declared length above `MAX_PAYLOAD`); `next_frame` turns it into an `io::Error` of kind `InvalidData` and returns it.
3. The `usize` is the total number of bytes the frame occupied in the buffer (header plus payload, `HEADER_LEN + len`), which `next_frame` drains from the front of `rbuf` so any following bytes stay buffered for the next call.

Mentioning that `next_frame` returns `Ok(None)` when the socket reaches EOF (and that a partial frame left in `rbuf` is then dropped silently) is a plus but not required. FAIL if any of the three points is missing or wrong (e.g. describing `Ok(None)` as "no frame / empty stream" with no mention of needing more data, or the `usize` as the payload length).
