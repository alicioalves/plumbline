---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I can't come up with a good name for `process_and_update` in our token manager. Any ideas? Here's the file.

```rust
// src/auth/token.rs
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};

use crate::http::{HttpClient, HttpResponse};
use crate::metrics::Metrics;

const TOKEN_URL: &str = "https://auth.internal/oauth/token";

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
    refresh_token: Option<String>,
    scope: String,
}

#[derive(Serialize)]
struct CachedTokens<'a> {
    access_token: &'a str,
    refresh_token: &'a str,
    expires_at_unix: u64,
}

pub struct AccessToken {
    value: String,
    expires_at: SystemTime,
    scopes: Vec<String>,
}

pub struct TokenManager {
    http: HttpClient,
    metrics: Metrics,
    cache_path: PathBuf,
    token: Option<AccessToken>,
    refresh_token: String,
    next_refresh: Option<Instant>,
}

impl TokenManager {
    pub fn is_valid(&mut self) -> bool {
        if let Some(t) = &self.token {
            if t.expires_at > SystemTime::now() + Duration::from_secs(60) {
                return true;
            }
        }
        let form = [("grant_type", "refresh_token"), ("refresh_token", self.refresh_token.as_str())];
        match self.http.post_form(TOKEN_URL, &form) {
            Ok(resp) => self.process_and_update(resp).is_ok(),
            Err(_) => false,
        }
    }

    pub fn authorization_header(&mut self) -> Option<String> {
        if !self.is_valid() {
            return None;
        }
        self.token.as_ref().map(|t| format!("Bearer {}", t.value))
    }

    pub fn has_scope(&self, scope: &str) -> bool {
        self.token.as_ref().map_or(false, |t| t.scopes.iter().any(|s| s == scope))
    }

    fn process_and_update(&mut self, resp: HttpResponse) -> Result<(), AuthError> {
        if resp.status != 200 {
            self.metrics.incr("auth.refresh.failed");
            return Err(AuthError::Refresh(resp.status));
        }
        let body: TokenResponse = serde_json::from_slice(&resp.body)?;
        if let Some(rt) = body.refresh_token {
            self.refresh_token = rt;
        }
        let expires_at = SystemTime::now() + Duration::from_secs(body.expires_in);
        let cached = CachedTokens {
            access_token: &body.access_token,
            refresh_token: &self.refresh_token,
            expires_at_unix: expires_at.duration_since(UNIX_EPOCH).unwrap().as_secs(),
        };
        fs::write(&self.cache_path, serde_json::to_vec(&cached)?)?;
        self.token = Some(AccessToken {
            value: body.access_token,
            expires_at,
            scopes: body.scope.split(' ').map(String::from).collect(),
        });
        self.metrics.incr("auth.refresh.ok");
        self.metrics.gauge("auth.token.ttl_secs", body.expires_in as f64);
        self.next_refresh = Some(Instant::now() + Duration::from_secs(body.expires_in.saturating_sub(120)));
        Ok(())
    }
}
```
