---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
`test_bulk_discount` fails. Fix the bug and show the corrected function.

```python
def bulk_total(qty: int, price_cents: int) -> int:
    """20% off when qty is at least 10. Otherwise full price."""
    total = qty * price_cents
    if qty > 10:
        total = total * 80 // 100
    return total


def test_bulk_discount():
    assert bulk_total(10, 500) == 4000
```

The failure is `assert 5000 == 4000`.
