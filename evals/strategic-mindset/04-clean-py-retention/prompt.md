---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We wrote this data-retention job under a deadline last sprint (legal needed it before the audit). Before we build more on it: did we cut corners? Is this tactical code we're going to pay for later?

```python
# retention/policies.py
"""How long each kind of record is kept. Legal owns these numbers; change them only here."""

from dataclasses import dataclass
from datetime import timedelta


@dataclass(frozen=True)
class Policy:
    table: str
    timestamp_column: str  # a row is expired once this is older than max_age
    max_age: timedelta


POLICIES = (
    Policy("login_events", "occurred_at", timedelta(days=90)),
    Policy("support_messages", "created_at", timedelta(days=2 * 365)),
    Policy("payment_attempts", "attempted_at", timedelta(days=7 * 365)),
)
```

```python
# retention/purge.py
"""Delete records that have outlived their retention policy.

Runs nightly. Safe to stop and rerun at any point: each batch commits on its
own, and a rerun simply finds whatever is still past its age.
"""

import argparse
import logging
import os
from datetime import datetime, timezone

import psycopg
from psycopg import sql

from .policies import POLICIES, Policy

log = logging.getLogger(__name__)

BATCH_SIZE = 5_000  # small enough that no single delete holds locks for long


def purge_expired(conninfo: str, *, now: datetime | None = None, dry_run: bool = False) -> dict[str, int]:
    """Apply every policy. Returns rows deleted per table (with dry_run, rows that would be)."""
    now = now or datetime.now(timezone.utc)
    # Autocommit: every batch is its own transaction, so the purge never holds one huge transaction open.
    with psycopg.connect(conninfo, autocommit=True) as conn:
        return {p.table: _purge(conn, p, now - p.max_age, dry_run) for p in POLICIES}


def _purge(conn: psycopg.Connection, policy: Policy, cutoff: datetime, dry_run: bool) -> int:
    names = {"t": sql.Identifier(policy.table), "c": sql.Identifier(policy.timestamp_column)}
    if dry_run:
        count = sql.SQL("SELECT count(*) FROM {t} WHERE {c} < %s").format(**names)
        return conn.execute(count, (cutoff,)).fetchone()[0]
    delete_batch = sql.SQL(
        "DELETE FROM {t} WHERE ctid IN (SELECT ctid FROM {t} WHERE {c} < %s LIMIT %s)"
    ).format(**names)
    deleted = 0
    while True:
        n = conn.execute(delete_batch, (cutoff, BATCH_SIZE)).rowcount
        deleted += n
        if n < BATCH_SIZE:
            log.info("purged %d rows from %s older than %s", deleted, policy.table, cutoff.date())
            return deleted


def main() -> None:
    parser = argparse.ArgumentParser(description="Delete records past their retention period.")
    parser.add_argument("--dry-run", action="store_true", help="report counts without deleting")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    for table, n in purge_expired(os.environ["DATABASE_URL"], dry_run=args.dry_run).items():
        print(f"{table}: {n}")
```

```python
# tests/test_purge.py (the db fixture creates the tables in a throwaway database)
from datetime import datetime, timedelta, timezone

from retention.purge import purge_expired

NOW = datetime(2026, 6, 1, tzinfo=timezone.utc)


def test_deletes_only_rows_past_their_policy(db):
    db.insert("login_events", occurred_at=NOW - timedelta(days=91))
    db.insert("login_events", occurred_at=NOW - timedelta(days=89))
    assert purge_expired(db.conninfo, now=NOW)["login_events"] == 1
    assert db.count("login_events") == 1


def test_dry_run_counts_without_deleting(db):
    db.insert("login_events", occurred_at=NOW - timedelta(days=91))
    assert purge_expired(db.conninfo, now=NOW, dry_run=True)["login_events"] == 1
    assert db.count("login_events") == 1
```
