---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I have to change `parse_amount` next week and there are no tests. Pin what it does today. Do not change the function, and do not expose anything it keeps private.

```python
import re

_AMOUNT = re.compile(r"^\$?(?P<whole>\d+)(?:\.(?P<frac>\d{2}))?$")

def parse_amount(text: str) -> int:
    """Dollars and cents as an int of cents. Private helper, not a stable format."""
    m = _AMOUNT.match(text.strip())
    if not m:
        raise ValueError(text)
    whole = int(m.group("whole"))
    frac = m.group("frac")
    return whole * 100 + (int(frac) if frac else 0)
```
