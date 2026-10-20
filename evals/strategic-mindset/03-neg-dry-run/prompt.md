---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We threw this cleanup script together a while ago and it runs nightly. Please add a `--dry-run` flag: when it's set, the script should print each object key it would delete and the total size it would free, but not delete anything. Show me the updated script.

```python
#!/usr/bin/env python3
"""Delete stale build artifacts from the CI bucket."""
import argparse
import sys
from datetime import datetime, timedelta, timezone

import boto3

BUCKET = "ci-artifacts-prod"
# TODO: move to config, ops wants per-repo retention
RETENTION_DAYS = 30
KEEP_PREFIXES = ("releases/", "nightly/latest/")
BATCH_SIZE = 1000  # S3 DeleteObjects limit


def stale_objects(s3, cutoff):
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET):
        for obj in page.get("Contents", []):
            if obj["Key"].startswith(KEEP_PREFIXES):
                continue
            if obj["LastModified"] < cutoff:
                yield obj


def delete_batch(s3, keys):
    resp = s3.delete_objects(
        Bucket=BUCKET,
        Delete={"Objects": [{"Key": k} for k in keys], "Quiet": True},
    )
    errors = resp.get("Errors", [])
    for err in errors:
        print(f"failed to delete {err['Key']}: {err['Message']}", file=sys.stderr)
    return len(keys) - len(errors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=RETENTION_DAYS)
    args = parser.parse_args()

    cutoff = datetime.now(timezone.utc) - timedelta(days=args.days)
    s3 = boto3.client("s3")

    batch, deleted, freed = [], 0, 0
    for obj in stale_objects(s3, cutoff):
        batch.append(obj["Key"])
        freed += obj["Size"]
        if len(batch) == BATCH_SIZE:
            deleted += delete_batch(s3, batch)
            batch = []
    if batch:
        deleted += delete_batch(s3, batch)

    print(f"deleted {deleted} objects, freed {freed / 1e9:.2f} GB")


if __name__ == "__main__":
    main()
```
