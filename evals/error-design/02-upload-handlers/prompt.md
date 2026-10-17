---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
In our Rust upload service the error handling is now longer than the actual logic in every handler, and I'm about to add three more endpoints. How should errors work here before I copy this pattern again?

```rust
// src/handlers.rs
use crate::http::{Request, Response, StatusCode};
use crate::storage::{BlobDir, StorageError};

#[derive(Debug)]
pub enum ParamError {
    Missing(&'static str),
    NotANumber(&'static str),
    OutOfRange(&'static str),
}

fn param<'a>(req: &'a Request, name: &'static str) -> Result<&'a str, ParamError> {
    req.query(name).ok_or(ParamError::Missing(name))
}

fn param_u64(req: &Request, name: &'static str, max: u64) -> Result<u64, ParamError> {
    let raw = param(req, name)?;
    let n: u64 = raw.parse().map_err(|_| ParamError::NotANumber(name))?;
    if n > max {
        return Err(ParamError::OutOfRange(name));
    }
    Ok(n)
}

pub fn upload(req: &Request, dir: &BlobDir) -> Response {
    let name = match param(req, "name") {
        Ok(n) => n,
        Err(ParamError::Missing(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("missing parameter: {p}")),
        Err(e) => return Response::text(StatusCode::BAD_REQUEST, format!("bad parameter: {e:?}")),
    };
    let size = match param_u64(req, "size", 512 * 1024 * 1024) {
        Ok(n) => n,
        Err(ParamError::Missing(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("missing parameter: {p}")),
        Err(ParamError::NotANumber(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} must be a number")),
        Err(ParamError::OutOfRange(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} is too large")),
    };
    if req.body().len() as u64 != size {
        return Response::text(StatusCode::BAD_REQUEST, "size does not match body");
    }
    match dir.save(name, req.body()) {
        Ok(()) => Response::empty(StatusCode::CREATED),
        Err(StorageError::InvalidName) => Response::text(StatusCode::BAD_REQUEST, "invalid name"),
        Err(StorageError::NotFound) => Response::text(StatusCode::NOT_FOUND, "not found"),
        Err(StorageError::Io(e)) => {
            log::error!("save {name}: {e}");
            Response::text(StatusCode::INTERNAL_SERVER_ERROR, "storage error")
        }
    }
}

pub fn download(req: &Request, dir: &BlobDir) -> Response {
    let name = match param(req, "name") {
        Ok(n) => n,
        Err(ParamError::Missing(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("missing parameter: {p}")),
        Err(e) => return Response::text(StatusCode::BAD_REQUEST, format!("bad parameter: {e:?}")),
    };
    let offset = match param_u64(req, "offset", u64::MAX) {
        Ok(n) => n,
        Err(ParamError::Missing(_)) => 0,
        Err(ParamError::NotANumber(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} must be a number")),
        Err(ParamError::OutOfRange(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} is too large")),
    };
    let len = match param_u64(req, "len", 16 * 1024 * 1024) {
        Ok(n) => n,
        Err(ParamError::Missing(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("missing parameter: {p}")),
        Err(ParamError::NotANumber(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} must be a number")),
        Err(ParamError::OutOfRange(p)) => return Response::text(StatusCode::BAD_REQUEST, format!("{p} is too large")),
    };
    match dir.read_range(name, offset, len) {
        Ok(bytes) => Response::bytes(StatusCode::OK, bytes),
        Err(StorageError::InvalidName) => Response::text(StatusCode::BAD_REQUEST, "invalid name"),
        Err(StorageError::NotFound) => Response::text(StatusCode::NOT_FOUND, "not found"),
        Err(StorageError::Io(e)) => {
            log::error!("read {name}: {e}");
            Response::text(StatusCode::INTERNAL_SERVER_ERROR, "storage error")
        }
    }
}
```

```rust
// src/storage.rs (excerpt)
pub enum StorageError {
    InvalidName,
    NotFound,
    Io(io::Error),
}

impl BlobDir {
    pub fn save(&self, name: &str, data: &[u8]) -> Result<(), StorageError> {
        validate_name(name)?;
        let tmp = self.root.join(format!(".{name}.tmp"));
        let mut f = File::create(&tmp).map_err(StorageError::Io)?;
        f.write_all(data).map_err(StorageError::Io)?;
        if let Err(e) = f.sync_all() {
            log::warn!("fsync failed for {name}: {e}");
        }
        fs::rename(&tmp, self.root.join(name)).map_err(StorageError::Io)?;
        Ok(())
    }
}
```
