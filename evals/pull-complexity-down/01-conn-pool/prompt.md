---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Here's our connection pool and two of the clients built on it. It works, but every time someone writes a new client against it, something goes wrong. Anything you'd change about how the API is shaped?

```rust
// src/pool.rs
use std::io;
use std::net::TcpStream;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::net::is_alive;

pub struct PoolConfig {
    /// Maximum connections checked out at once.
    pub max_size: usize,
    /// Idle connections the maintenance thread keeps warm. Must not exceed `max_size`.
    pub min_idle: usize,
    /// Idle connections older than this are dropped on acquire.
    pub idle_timeout_ms: u64,
    /// How often the maintenance thread tops up idle connections.
    pub maintenance_interval_ms: u64,
    /// Probe each idle connection before handing it out.
    pub validate_on_borrow: bool,
}

#[derive(Debug)]
pub enum PoolError {
    Exhausted,
    Connect(io::Error),
}

pub struct Pool {
    addr: String,
    cfg: PoolConfig,
    idle: Mutex<Vec<(TcpStream, Instant)>>,
    in_use: AtomicUsize,
}

impl Pool {
    pub fn new(addr: &str, cfg: PoolConfig) -> Self {
        Self { addr: addr.to_string(), cfg, idle: Mutex::new(Vec::new()), in_use: AtomicUsize::new(0) }
    }

    /// Must be called once after construction, or idle connections are never replenished.
    pub fn spawn_maintenance(self: &Arc<Self>) {
        let pool = Arc::clone(self);
        thread::spawn(move || loop {
            thread::sleep(Duration::from_millis(pool.cfg.maintenance_interval_ms));
            let mut idle = pool.idle.lock().unwrap();
            while idle.len() < pool.cfg.min_idle {
                match TcpStream::connect(&pool.addr) {
                    Ok(conn) => idle.push((conn, Instant::now())),
                    Err(_) => break,
                }
            }
        });
    }

    pub fn acquire(&self) -> Result<TcpStream, PoolError> {
        let mut idle = self.idle.lock().unwrap();
        while let Some((conn, since)) = idle.pop() {
            if since.elapsed() > Duration::from_millis(self.cfg.idle_timeout_ms) {
                continue;
            }
            if self.cfg.validate_on_borrow && !is_alive(&conn) {
                continue;
            }
            self.in_use.fetch_add(1, Ordering::SeqCst);
            return Ok(conn);
        }
        drop(idle);
        if self.in_use.load(Ordering::SeqCst) >= self.cfg.max_size {
            return Err(PoolError::Exhausted);
        }
        let conn = TcpStream::connect(&self.addr).map_err(PoolError::Connect)?;
        self.in_use.fetch_add(1, Ordering::SeqCst);
        Ok(conn)
    }

    /// Return a healthy connection. If the connection saw an I/O error, call `discard` instead.
    pub fn release(&self, conn: TcpStream) {
        self.in_use.fetch_sub(1, Ordering::SeqCst);
        self.idle.lock().unwrap().push((conn, Instant::now()));
    }

    pub fn discard(&self, conn: TcpStream) {
        self.in_use.fetch_sub(1, Ordering::SeqCst);
        drop(conn);
    }
}
```

```rust
// src/cache_client.rs
pub fn connect_cache(addr: &str) -> Arc<Pool> {
    let pool = Arc::new(Pool::new(addr, PoolConfig {
        max_size: 16,
        min_idle: 2,
        idle_timeout_ms: 30_000,
        maintenance_interval_ms: 10_000,
        validate_on_borrow: true,
    }));
    pool.spawn_maintenance();
    pool
}

pub fn cache_get(pool: &Pool, key: &str) -> io::Result<Option<Vec<u8>>> {
    let mut conn = match pool.acquire() {
        Ok(c) => c,
        Err(PoolError::Exhausted) => return Err(io::Error::new(io::ErrorKind::WouldBlock, "cache pool exhausted")),
        Err(PoolError::Connect(e)) => return Err(e),
    };
    match protocol::get(&mut conn, key) {
        Ok(value) => {
            pool.release(conn);
            Ok(value)
        }
        Err(e) => {
            pool.discard(conn);
            Err(e)
        }
    }
}
```

```rust
// src/queue_client.rs
pub fn connect_queue(addr: &str) -> Arc<Pool> {
    let pool = Arc::new(Pool::new(addr, PoolConfig {
        max_size: 16,
        min_idle: 2,
        idle_timeout_ms: 30_000,
        maintenance_interval_ms: 10_000,
        validate_on_borrow: true,
    }));
    pool.spawn_maintenance();
    pool
}

pub fn publish(pool: &Pool, topic: &str, msg: &[u8]) -> io::Result<()> {
    let mut conn = match pool.acquire() {
        Ok(c) => c,
        Err(PoolError::Exhausted) => return Err(io::Error::new(io::ErrorKind::WouldBlock, "queue pool exhausted")),
        Err(PoolError::Connect(e)) => return Err(e),
    };
    protocol::send_frame(&mut conn, topic, msg)?;
    match protocol::read_ack(&mut conn) {
        Ok(()) => {
            pool.release(conn);
            Ok(())
        }
        Err(e) => {
            pool.discard(conn);
            Err(e)
        }
    }
}
```
