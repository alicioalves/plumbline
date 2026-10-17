---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Can you review the error handling in this module? I want to make sure we're not swallowing things we shouldn't, and not making callers deal with failures they shouldn't have to.

```python
# cache/disk_cache.py
"""A persistent on-disk cache for expensive values that can always be recomputed.

The cache is never the source of truth, and that shapes its error handling: an
entry that is missing, expired or unreadable is simply a miss, and failing to
store an entry costs a recomputation later, not correctness now.
"""

import contextlib
import hashlib
import json
import logging
import os
import tempfile
import time
from pathlib import Path
from typing import Any, Callable

log = logging.getLogger(__name__)


class DiskCache:
    def __init__(self, directory: Path, ttl_seconds: float) -> None:
        """Keep values under directory (created if needed) for ttl_seconds.

        Raises OSError if the directory can't be created: a cache pointed at an
        unusable location is a deployment mistake worth failing loudly on.
        """
        directory.mkdir(parents=True, exist_ok=True)
        self._dir = directory
        self._ttl = ttl_seconds

    def get_or_compute(self, key: str, compute: Callable[[], Any]) -> Any:
        """Return the cached value for key, or call compute(), cache its result and return it.

        Values come back as JSON decodes them (tuples become lists). Exceptions
        from compute() propagate unchanged and nothing is cached. A result that
        isn't JSON-serializable raises TypeError: that's a bug in the caller,
        not a cache failure.
        """
        path = self._path(key)
        hit = self._read(path)
        if hit is not None:
            return hit[0]
        value = compute()
        self._write(path, value)
        return value

    def invalidate(self, key: str) -> None:
        """Make the next lookup of key a miss. Invalidating an absent key is fine."""
        self._path(key).unlink(missing_ok=True)

    def _path(self, key: str) -> Path:
        # Hashing makes every key a valid, fixed-length file name.
        return self._dir / hashlib.sha256(key.encode()).hexdigest()

    def _read(self, path: Path) -> tuple[Any] | None:
        """The cached value in a 1-tuple (so a cached None is still a hit), or None on a miss."""
        try:
            with path.open(encoding="utf-8") as f:
                entry = json.load(f)
            stored_at, value = entry["stored_at"], entry["value"]
            expired = time.time() - stored_at > self._ttl
        except FileNotFoundError:
            return None
        except (OSError, ValueError, KeyError, TypeError) as e:
            # Truncated, corrupt or unreadable: drop it and let the caller recompute.
            log.warning("discarding unreadable cache entry %s: %s", path.name, e)
            with contextlib.suppress(OSError):
                path.unlink(missing_ok=True)
            return None
        return None if expired else (value,)

    def _write(self, path: Path, value: Any) -> None:
        """Store value at path atomically. If the disk refuses, log it and carry on uncached."""
        payload = json.dumps({"stored_at": time.time(), "value": value})
        try:
            fd, tmp = tempfile.mkstemp(dir=self._dir, prefix=".tmp-")
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as f:
                    f.write(payload)
                os.replace(tmp, path)  # readers see the old entry or the new one, never half
            except BaseException:
                with contextlib.suppress(OSError):
                    os.unlink(tmp)
                raise
        except OSError as e:
            log.warning("could not cache entry %s: %s", path.name, e)
```
