---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
This module feels like it's going to be hard to work with, but I can't point at anything specific. Is there real complexity in here, and if so, where is it coming from?

```python
# flags/rollout.py
"""Decide whether a feature flag is on for a given user.

A flag is rolled out to a percentage of users. Each user's answer is stable
(the same on every request and every server) and monotonic (raising the
percentage only ever turns the flag on for more users, never off for someone
who already had it).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field
from typing import Any, Mapping


@dataclass(frozen=True)
class Rollout:
    flag: str
    percent: float
    """Share of users who get the flag, from 0 (nobody) to 100 (everyone)."""
    always_on: frozenset[str] = field(default_factory=frozenset)
    """User ids that get the flag regardless of percent, e.g. internal testers."""

    def __post_init__(self) -> None:
        if not 0 <= self.percent <= 100:
            raise ValueError(f"{self.flag}: percent must be between 0 and 100, got {self.percent}")

    def is_enabled_for(self, user_id: str) -> bool:
        if user_id in self.always_on:
            return True
        return _bucket(self.flag, user_id) < self.percent


def _bucket(flag: str, user_id: str) -> float:
    """Map (flag, user) to a stable point in [0, 100).

    The flag name is part of the hash so that each flag picks a different
    slice of users; otherwise the same 5% would get every experiment.
    """
    digest = hashlib.sha256(f"{flag}:{user_id}".encode()).digest()
    return int.from_bytes(digest[:8], "big") / 2**64 * 100


def load_rollouts(config: Mapping[str, Mapping[str, Any]]) -> dict[str, Rollout]:
    """Build rollouts from the parsed ``flags:`` section of the service config.

    Each entry looks like ``{"percent": 25, "always_on": ["u_123"]}``, with
    ``always_on`` optional. Raises ValueError naming the flag if an entry is
    malformed, so a bad config fails at startup rather than on some request.
    """
    rollouts = {}
    for flag, entry in config.items():
        try:
            percent = float(entry["percent"])
        except (KeyError, TypeError, ValueError) as e:
            raise ValueError(f"{flag}: 'percent' must be a number") from e
        rollouts[flag] = Rollout(flag, percent, frozenset(entry.get("always_on", ())))
    return rollouts
```

