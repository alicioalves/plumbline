---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I'm new to this codebase. Can you explain what `parse_frame` returns — specifically what `Ok(None)`, `Err(..)` and the `usize` in `Ok(Some(..))` each mean — and how `next_frame` uses them?

```rust
// src/codec.rs
use std::io::{self, Read, Write};

const MAGIC: u16 = 0xCAFE;
const HEADER_LEN: usize = 10;
pub const MAX_PAYLOAD: usize = 1 << 20;

#[derive(Debug)]
pub enum FrameError {
    BadMagic(u16),
    UnknownKind(u8),
    TooLarge(usize),
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Kind {
    Data,
    Ping,
    Close,
}

#[derive(Debug)]
pub struct Frame {
    pub kind: Kind,
    pub stream: u16,
    pub payload: Vec<u8>,
}

pub fn parse_frame(buf: &[u8]) -> Result<Option<(Frame, usize)>, FrameError> {
    if buf.len() < HEADER_LEN {
        return Ok(None);
    }
    let magic = u16::from_be_bytes([buf[0], buf[1]]);
    if magic != MAGIC {
        return Err(FrameError::BadMagic(magic));
    }
    let kind = match buf[2] {
        0 => Kind::Data,
        1 => Kind::Ping,
        2 => Kind::Close,
        k => return Err(FrameError::UnknownKind(k)),
    };
    let stream = u16::from_be_bytes([buf[4], buf[5]]);
    let len = u32::from_be_bytes([buf[6], buf[7], buf[8], buf[9]]) as usize;
    if len > MAX_PAYLOAD {
        return Err(FrameError::TooLarge(len));
    }
    let total = HEADER_LEN + len;
    if buf.len() < total {
        return Ok(None);
    }
    let payload = buf[HEADER_LEN..total].to_vec();
    Ok(Some((Frame { kind, stream, payload }, total)))
}

pub fn write_frame<W: Write>(w: &mut W, kind: Kind, stream: u16, payload: &[u8]) -> io::Result<()> {
    let mut header = [0u8; 10];
    header[..2].copy_from_slice(&0xCAFEu16.to_be_bytes());
    header[2] = kind as u8;
    header[4..6].copy_from_slice(&stream.to_be_bytes());
    header[6..10].copy_from_slice(&(payload.len() as u32).to_be_bytes());
    w.write_all(&header)?;
    w.write_all(payload)
}

pub struct Conn<S> {
    sock: S,
    rbuf: Vec<u8>,
}

impl<S: Read> Conn<S> {
    pub fn new(sock: S) -> Self {
        Self { sock, rbuf: Vec::with_capacity(16 * 1024) }
    }

    pub fn next_frame(&mut self) -> io::Result<Option<Frame>> {
        loop {
            match parse_frame(&self.rbuf) {
                Ok(Some((frame, used))) => {
                    self.rbuf.drain(..used);
                    return Ok(Some(frame));
                }
                Ok(None) => {}
                Err(e) => return Err(io::Error::new(io::ErrorKind::InvalidData, format!("{e:?}"))),
            }
            let mut chunk = [0u8; 8192];
            let n = self.sock.read(&mut chunk)?;
            if n == 0 {
                return Ok(None);
            }
            self.rbuf.extend_from_slice(&chunk[..n]);
        }
    }
}
```
