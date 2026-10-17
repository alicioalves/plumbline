---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Bug: if the frontend requests a thumbnail before the resize worker has uploaded it, `CachedBlobStore.get` keeps returning `None` for that key for ten minutes, even after the worker's `put` succeeds. Fix `CachedBlobStore` so a blob is visible on the very next `get` after it is `put`. Show me the corrected class.

```python
# storage/blobs.py
class BlobStore:
    def __init__(self, client, bucket):
        self.client = client
        self.bucket = bucket

    def get(self, key):
        try:
            obj = self.client.get_object(Bucket=self.bucket, Key=key)
        except self.client.exceptions.NoSuchKey:
            return None
        return obj["Body"].read()

    def put(self, key, data, content_type="application/octet-stream"):
        self.client.put_object(Bucket=self.bucket, Key=key, Body=data, ContentType=content_type)

    def delete(self, key):
        self.client.delete_object(Bucket=self.bucket, Key=key)

    def list_prefix(self, prefix):
        keys = []
        paginator = self.client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
            keys.extend(item["Key"] for item in page.get("Contents", []))
        return keys


class CachedBlobStore:
    def __init__(self, store, cache, ttl=600):
        self.store = store
        self.cache = cache
        self.ttl = ttl

    def get(self, key):
        cache_key = f"blob:{key}"
        if self.cache.has(cache_key):
            return self.cache.get(cache_key)
        data = self.store.get(key)
        self.cache.set(cache_key, data, ttl=self.ttl)
        return data

    def put(self, key, data, content_type="application/octet-stream"):
        self.store.put(key, data, content_type)

    def delete(self, key):
        self.store.delete(key)
        self.cache.delete(f"blob:{key}")

    def list_prefix(self, prefix):
        return self.store.list_prefix(prefix)
```

```python
# thumbnails/views.py
def thumbnail(request, image_id, size):
    data = blobs.get(f"thumbs/{image_id}/{size}.webp")
    if data is None:
        enqueue_resize(image_id, size)
        return HttpResponse(status=202)
    return HttpResponse(data, content_type="image/webp")
```
