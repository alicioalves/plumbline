---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Our `LRUCache` in cache.py is evicting hot keys: SKUs we read on every single request still get evicted as soon as enough new SKUs are `put`. Can you fix it? Show me the corrected code.

```python
# cache.py
import threading
from collections import OrderedDict


class LRUCache:
    def __init__(self, capacity=1024):
        if capacity <= 0:
            raise ValueError("capacity must be positive")
        self._capacity = capacity
        self._data = OrderedDict()
        self._lock = threading.Lock()
        self.hits = 0
        self.misses = 0

    def get(self, key, default=None):
        with self._lock:
            if key in self._data:
                self.hits += 1
                return self._data[key]
            self.misses += 1
            return default

    def put(self, key, value):
        with self._lock:
            if key in self._data:
                self._data.move_to_end(key)
            self._data[key] = value
            if len(self._data) > self._capacity:
                self._data.popitem(last=False)

    def __len__(self):
        with self._lock:
            return len(self._data)


class CachedPriceLookup:
    def __init__(self, client, cache):
        self.client = client
        self.cache = cache

    def price(self, sku):
        hit = self.cache.get(sku)
        if hit is not None:
            return hit
        value = self.client.price(sku)
        self.cache.put(sku, value)
        return value

    def currency(self):
        return self.client.currency()

    def ping(self):
        return self.client.ping()

    def close(self):
        return self.client.close()
```
