---
type: llm
focus: last_message
---
PASS if the answer shows corrected code for `CachedBlobStore` in which, after `put(key, data)` returns, the next `get(key)` returns `data` both when the key was previously cached as a miss (`None`) and when it was previously cached with older bytes. That requires `put` to invalidate or overwrite the `blob:{key}` cache entry (with `cache.delete` or `cache.set`); also not caching misses is fine but is not sufficient on its own. The rest of the behavior (`get` still caches hits, `delete` still invalidates) must keep working. FAIL if `put` does not touch the cache, if the fix is only described in prose without code, or if it breaks caching of hits.
