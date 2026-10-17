---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Can you review the comments in this module? We're about to publish it as an internal package, and most teams will only ever read the doc comments, not the code.

```typescript
// rate-limit/limiter.ts

/**
 * RateLimiter class.
 */
export class RateLimiter {
  // The store.
  private store: Map<string, Bucket> = new Map();
  // The limit.
  private readonly limit: number;
  // The window.
  private readonly windowMs: number;

  /**
   * Creates a new RateLimiter.
   * @param limit the limit
   * @param windowSeconds the window in seconds (default 60)
   */
  constructor(limit: number, windowMs = 30_000) {
    this.limit = limit;
    this.windowMs = windowMs;
  }

  /**
   * Tries to acquire.
   * @param key the key
   * @returns null if the limit is exceeded
   */
  tryAcquire(key: string, now = Date.now()): number {
    // get the bucket
    let bucket = this.store.get(key);
    // if there is no bucket or it has expired, create one
    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + this.windowMs };
      this.store.set(key, bucket);
    }
    // check if count is greater than or equal to limit
    if (bucket.count >= this.limit) {
      return bucket.resetAt - now;
    }
    // increment count
    bucket.count++;
    return 0;
  }

  /**
   * Resets the key.
   * @param key the key
   */
  reset(key: string): void {
    this.store.delete(key);
  }

  /**
   * Sweeps the store.
   */
  sweep(now = Date.now()): number {
    let removed = 0;
    // loop over the store
    for (const [key, bucket] of this.store) {
      if (now >= bucket.resetAt) {
        this.store.delete(key);
        removed++;
      }
    }
    return removed;
  }
}

interface Bucket {
  // the count
  count: number;
  // reset at
  resetAt: number;
}
```

```typescript
// rate-limit/middleware.ts
import type { RequestHandler } from "express";
import { RateLimiter } from "./limiter";

/**
 * Express middleware for rate limiting.
 */
export function rateLimit(limiter: RateLimiter): RequestHandler {
  return (req, res, next) => {
    if (limiter.tryAcquire(req.ip) === null) {
      res.status(429).send("Too Many Requests");
      return;
    }
    next();
  };
}
```
