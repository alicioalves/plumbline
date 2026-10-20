---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
store.rs keeps growing and I'm wondering whether to break it up. Should I, and if so where would you draw the line?

```rust
// src/store.rs
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::PathBuf;

use sha2::{Digest, Sha256};

const MAGIC: [u8; 4] = *b"BLB1";
const HEADER_LEN: usize = 13;
const COMPRESS_ABOVE: usize = 4096;

pub struct TenantStore {
    root: PathBuf,
    usage_bytes: HashMap<String, u64>,
    plan_limits: HashMap<String, u64>,
    price_per_gb_cents: u64,
}

impl TenantStore {
    pub fn new(root: PathBuf, price_per_gb_cents: u64) -> Self {
        Self { root, usage_bytes: HashMap::new(), plan_limits: HashMap::new(), price_per_gb_cents }
    }

    pub fn set_plan_limit(&mut self, tenant: &str, bytes: u64) {
        self.plan_limits.insert(tenant.to_string(), bytes);
    }

    pub fn put(&mut self, tenant: &str, data: &[u8]) -> io::Result<String> {
        let compressed = data.len() > COMPRESS_ABOVE;
        let body = if compressed { lz4_flex::compress_prepend_size(data) } else { data.to_vec() };
        let stored = (HEADER_LEN + body.len()) as u64;
        let used = self.usage(tenant);
        if let Some(limit) = self.plan_limits.get(tenant) {
            if used + stored > *limit {
                return Err(io::Error::new(io::ErrorKind::Other, format!("{tenant}: quota exceeded")));
            }
        }

        let id = hex::encode(Sha256::digest(data));
        let path = self.root.join(tenant).join(&id);
        fs::create_dir_all(path.parent().unwrap())?;
        let mut f = File::create(&path)?;
        f.write_all(&MAGIC)?;
        f.write_all(&[compressed as u8])?;
        f.write_all(&(data.len() as u64).to_le_bytes())?;
        f.write_all(&body)?;
        *self.usage_bytes.entry(tenant.to_string()).or_insert(0) += stored;
        Ok(id)
    }

    pub fn get(&self, tenant: &str, id: &str) -> io::Result<Vec<u8>> {
        let mut buf = Vec::new();
        File::open(self.root.join(tenant).join(id))?.read_to_end(&mut buf)?;
        if buf.len() < HEADER_LEN || buf[..4] != MAGIC {
            return Err(invalid("bad blob header"));
        }
        let compressed = buf[4] == 1;
        let raw_len = u64::from_le_bytes(buf[5..13].try_into().unwrap()) as usize;
        let body = &buf[HEADER_LEN..];
        if compressed {
            lz4_flex::decompress_size_prepended(body).map_err(|_| invalid("corrupt blob"))
        } else {
            Ok(body[..raw_len].to_vec())
        }
    }

    pub fn delete(&mut self, tenant: &str, id: &str) -> io::Result<()> {
        let path = self.root.join(tenant).join(id);
        let stored = fs::metadata(&path)?.len();
        fs::remove_file(path)?;
        if let Some(used) = self.usage_bytes.get_mut(tenant) {
            *used = used.saturating_sub(stored);
        }
        Ok(())
    }

    pub fn usage(&self, tenant: &str) -> u64 {
        self.usage_bytes.get(tenant).copied().unwrap_or(0)
    }

    /// Recomputes usage from disk after a restart.
    pub fn rebuild_usage(&mut self) -> io::Result<()> {
        self.usage_bytes.clear();
        for tenant_dir in fs::read_dir(&self.root)? {
            let tenant_dir = tenant_dir?;
            let tenant = tenant_dir.file_name().to_string_lossy().into_owned();
            let mut total = 0;
            for blob in fs::read_dir(tenant_dir.path())? {
                total += blob?.metadata()?.len();
            }
            self.usage_bytes.insert(tenant, total);
        }
        Ok(())
    }

    pub fn invoice_line(&self, tenant: &str, month: &str) -> String {
        let gb = (self.usage(tenant) + 999_999_999) / 1_000_000_000;
        let cents = gb * self.price_per_gb_cents;
        format!("{month}\t{tenant}\tstorage\t{gb} GB\t{}.{:02}", cents / 100, cents % 100)
    }
}

fn invalid(msg: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, msg.to_string())
}
```
