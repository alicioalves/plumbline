---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We're planning to move sessions from Redis to Postgres next quarter. `SessionStore` is small, so I figured it's basically a one-file change. Anything I should know before I scope it? Here's the store and everything that imports it.

```python
# sessions/store.py
import json
import secrets
import time

import redis

SESSION_TTL = 60 * 60 * 24 * 14


class SessionStore:
    def __init__(self, url):
        self._redis = redis.Redis.from_url(url, decode_responses=True)

    @property
    def client(self):
        return self._redis

    def create(self, user_id, device_id, ip):
        token = secrets.token_urlsafe(32)
        key = f"sess:{user_id}:{device_id}"
        self._redis.hset(key, mapping={
            "token": token,
            "data": json.dumps({"ip": ip, "created": int(time.time())}),
        })
        self._redis.expire(key, SESSION_TTL)
        return token

    def validate(self, user_id, device_id, token):
        stored = self._redis.hget(f"sess:{user_id}:{device_id}", "token")
        return stored is not None and secrets.compare_digest(stored, token)

    def destroy(self, user_id, device_id):
        self._redis.delete(f"sess:{user_id}:{device_id}")
```

```python
# accounts/security.py
def force_logout_everywhere(sessions, user_id, audit):
    r = sessions.client
    keys = list(r.scan_iter(match=f"sess:{user_id}:*"))
    if keys:
        r.delete(*keys)
    audit.record("force_logout", user_id=user_id, sessions=len(keys))
```

```python
# admin/devices.py
import json
from datetime import datetime, timezone


def list_devices(sessions, user_id):
    r = sessions.client
    devices = []
    for key in r.scan_iter(match=f"sess:{user_id}:*"):
        device_id = key.split(":", 2)[2]
        meta = json.loads(r.hget(key, "data"))
        devices.append({
            "device_id": device_id,
            "ip": meta["ip"],
            "signed_in_at": datetime.fromtimestamp(meta["created"], tz=timezone.utc),
            "expires_in": r.ttl(key),
        })
    return sorted(devices, key=lambda d: d["signed_in_at"], reverse=True)
```

```python
# ops/metrics.py
def active_session_count(sessions):
    return sum(1 for _ in sessions.client.scan_iter(match="sess:*", count=1000))
```
