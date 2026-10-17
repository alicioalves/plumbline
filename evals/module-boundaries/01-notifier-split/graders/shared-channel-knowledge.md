---
type: llm
focus: last_message
---
PASS if the answer points out that knowledge of the channels is spread across all three classes: the set of channels (`"email"` / `"sms"`) is switched on in `TemplateRenderer.render`, `ChannelSelector` (both `select` and `address_for`) and `Dispatcher.dispatch`, and the payload dict's keys (`channel`, `subject`, `html`, `text`, `to`) are an unowned format the renderer writes and the dispatcher reads, AND draws the design consequence: adding a channel (e.g. push) or changing the payload shape forces coordinated edits to every class, so the boundary was drawn by processing step rather than around the knowledge each module owns.

FAIL if this shared channel/payload knowledge is not raised, or is mentioned only as a typing nit (e.g. "use a dataclass for the payload") with no point about the classes having to change together.
