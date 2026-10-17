---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We're about to let other teams use this connection pool. Does it ask too much of its callers? I'd rather find out before the API is out there.

```rust
//! A blocking connection pool. Callers ask for a connection, use it, and drop
//! it; the pool decides when to open, reuse or discard connections.

use std::io;
use std::ops::{Deref, DerefMut};
use std::sync::{Condvar, Mutex};

/// How the pool opens connections and tells whether one can be reused.
pub trait Connector {
    type Conn;
    fn connect(&self) -> io::Result<Self::Conn>;
    /// Whether `conn` can go back in the pool. Must be cheap and must not
    /// block: typically it checks a flag the connection sets when I/O on it fails.
    fn is_reusable(&self, conn: &Self::Conn) -> bool;
}

pub struct Pool<C: Connector> {
    connector: C,
    max_open: usize,
    state: Mutex<State<C::Conn>>,
    released: Condvar,
}

struct State<T> {
    idle: Vec<T>,
    /// Connections that exist: idle, on loan, or being opened.
    open: usize,
}

impl<C: Connector> Pool<C> {
    /// A pool that opens up to two connections per CPU, which suits blocking
    /// clients where each worker thread holds one connection at a time.
    pub fn new(connector: C) -> Self {
        let cpus = std::thread::available_parallelism().map_or(4, |n| n.get());
        Self::with_max_open(connector, 2 * cpus)
    }

    /// Like `new`, for callers that must stay under a server-side connection
    /// limit. Panics if `max_open` is 0.
    pub fn with_max_open(connector: C, max_open: usize) -> Self {
        assert!(max_open > 0, "a pool needs room for at least one connection");
        let state = Mutex::new(State { idle: Vec::new(), open: 0 });
        Pool { connector, max_open, state, released: Condvar::new() }
    }

    /// Lends out a connection: an idle one if any is still reusable, otherwise
    /// a new one, waiting if `max_open` are already on loan. Dropping the
    /// returned guard gives the connection back. Fails only if opening a new
    /// connection fails.
    pub fn get(&self) -> io::Result<Pooled<'_, C>> {
        let mut state = self.state.lock().unwrap();
        loop {
            while let Some(conn) = state.idle.pop() {
                if self.connector.is_reusable(&conn) {
                    return Ok(Pooled { pool: self, conn: Some(conn) });
                }
                state.open -= 1;
            }
            if state.open < self.max_open {
                state.open += 1;
                drop(state); // don't hold the lock while connecting
                return match self.connector.connect() {
                    Ok(conn) => Ok(Pooled { pool: self, conn: Some(conn) }),
                    Err(e) => {
                        self.forget_one();
                        Err(e)
                    }
                };
            }
            state = self.released.wait(state).unwrap();
        }
    }

    fn give_back(&self, conn: C::Conn) {
        if self.connector.is_reusable(&conn) {
            self.state.lock().unwrap().idle.push(conn);
            self.released.notify_one();
        } else {
            self.forget_one();
        }
    }

    fn forget_one(&self) {
        self.state.lock().unwrap().open -= 1;
        self.released.notify_one();
    }
}

/// A connection on loan from a `Pool`; use it like the connection itself.
pub struct Pooled<'a, C: Connector> {
    pool: &'a Pool<C>,
    conn: Option<C::Conn>, // Some until dropped
}

impl<C: Connector> Deref for Pooled<'_, C> {
    type Target = C::Conn;
    fn deref(&self) -> &C::Conn {
        self.conn.as_ref().unwrap()
    }
}

impl<C: Connector> DerefMut for Pooled<'_, C> {
    fn deref_mut(&mut self) -> &mut C::Conn {
        self.conn.as_mut().unwrap()
    }
}

impl<C: Connector> Drop for Pooled<'_, C> {
    fn drop(&mut self) {
        if let Some(conn) = self.conn.take() {
            self.pool.give_back(conn);
        }
    }
}
```

A typical caller (`PgConnector::is_reusable` returns `!conn.is_broken()`):

```rust
pub fn load_order(pool: &Pool<PgConnector>, id: OrderId) -> io::Result<Order> {
    let mut conn = pool.get()?;
    conn.query_order(id) // if this fails mid-I/O, conn is marked broken and the pool drops it
}
```
