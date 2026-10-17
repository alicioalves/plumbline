---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I'm building the text buffer for our editor. Is this interface general enough, or am I going to regret not putting editor-specific methods on it (backspace, delete-selection and so on)? The editor commands that use it are below it.

```rust
// buffer.rs
use std::ops::Range;

/// The text of one document. Positions are char indices: 0 is before the
/// first char and `len()` is after the last.
#[derive(Default)]
pub struct TextBuffer {
    chars: Vec<char>,
}

impl TextBuffer {
    pub fn new(text: &str) -> Self {
        TextBuffer { chars: text.chars().collect() }
    }

    /// Number of chars in the document.
    pub fn len(&self) -> usize {
        self.chars.len()
    }

    pub fn is_empty(&self) -> bool {
        self.chars.is_empty()
    }

    /// Inserts `text` so that its first char ends up at position `at`.
    /// Panics if `at > len()`.
    pub fn insert(&mut self, at: usize, text: &str) {
        self.chars.splice(at..at, text.chars());
    }

    /// Removes the chars in `range` and returns them; an empty range removes
    /// nothing. Panics if the range is reversed or extends past `len()`.
    pub fn delete(&mut self, range: Range<usize>) -> String {
        self.chars.drain(range).collect()
    }

    /// Copies out the chars in `range`, with the same panics as `delete`.
    pub fn text(&self, range: Range<usize>) -> String {
        self.chars[range].iter().collect()
    }
}
```

```rust
// commands.rs: editor actions, built on TextBuffer's general operations.
use crate::buffer::TextBuffer;
use std::ops::Range;

/// The caret, plus the anchor where a selection started, if any.
pub struct Cursor {
    pub pos: usize,
    pub anchor: Option<usize>,
}

impl Cursor {
    /// The selected range, if any text is selected.
    fn selection(&self) -> Option<Range<usize>> {
        let anchor = self.anchor?;
        (anchor != self.pos).then(|| anchor.min(self.pos)..anchor.max(self.pos))
    }

    fn collapse_to(&mut self, pos: usize) {
        self.pos = pos;
        self.anchor = None;
    }
}

/// Deletes the selected text, if any, leaving the caret where it began.
fn delete_selection(buf: &mut TextBuffer, cur: &mut Cursor) -> Option<String> {
    let sel = cur.selection()?;
    cur.collapse_to(sel.start);
    Some(buf.delete(sel))
}

pub fn backspace(buf: &mut TextBuffer, cur: &mut Cursor) {
    if delete_selection(buf, cur).is_none() && cur.pos > 0 {
        buf.delete(cur.pos - 1..cur.pos);
        cur.collapse_to(cur.pos - 1);
    }
}

pub fn delete_forward(buf: &mut TextBuffer, cur: &mut Cursor) {
    if delete_selection(buf, cur).is_none() && cur.pos < buf.len() {
        buf.delete(cur.pos..cur.pos + 1);
    }
}

pub fn type_text(buf: &mut TextBuffer, cur: &mut Cursor, text: &str) {
    delete_selection(buf, cur);
    buf.insert(cur.pos, text);
    cur.collapse_to(cur.pos + text.chars().count());
}

pub fn copy(buf: &TextBuffer, cur: &Cursor) -> Option<String> {
    cur.selection().map(|sel| buf.text(sel))
}
```
