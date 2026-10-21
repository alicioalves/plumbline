---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
What tests should I add for this? Don't write them yet. List the ones worth writing and the ones I should not bother with.

```python
class Price:
    def __init__(self, cents: int):
        if cents < 0:
            raise ValueError("cents")
        self._cents = cents

    @property
    def cents(self) -> int:
        return self._cents

    def times(self, qty: int) -> "Price":
        if qty < 0:
            raise ValueError("qty")
        return Price(self._cents * qty)

    def _format_debug(self) -> str:
        return f"Price<{self._cents}>"
```
