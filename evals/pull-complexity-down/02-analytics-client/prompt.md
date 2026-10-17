---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Here's our analytics API client and two jobs that use it. Writing a new job against it always takes longer than it should. Thoughts on the client?

```ts
// analytics/client.ts
import { HttpClient } from "../http";

export interface AnalyticsEvent {
  id: string;
  type: string;
  userId: string;
  occurredAt: string;
  props: Record<string, unknown>;
}

export interface EventPage {
  events: AnalyticsEvent[];
  nextCursor: string | null;
}

export class RangeTooLargeError extends Error {
  constructor(readonly maxDays: number) {
    super(`date range exceeds ${maxDays} days`);
  }
}

export class AnalyticsClient {
  static readonly MAX_RANGE_DAYS = 31;

  constructor(private http: HttpClient, private apiKey: string) {}

  async fetchEvents(opts: {
    from: Date;
    to: Date;
    type?: string;
    cursor?: string;
    pageSize?: number;
  }): Promise<EventPage> {
    const days = (opts.to.getTime() - opts.from.getTime()) / 86_400_000;
    if (days > AnalyticsClient.MAX_RANGE_DAYS) {
      throw new RangeTooLargeError(AnalyticsClient.MAX_RANGE_DAYS);
    }
    const res = await this.http.get("/v2/events", {
      headers: { authorization: `Bearer ${this.apiKey}` },
      query: {
        from: opts.from.toISOString(),
        to: opts.to.toISOString(),
        type: opts.type,
        cursor: opts.cursor,
        limit: opts.pageSize ?? 500,
      },
    });
    return { events: res.body.data, nextCursor: res.body.next ?? null };
  }
}
```

```ts
// jobs/quarterlyActiveUsers.ts
import { AnalyticsClient } from "../analytics/client";

const DAY_MS = 86_400_000;

export async function quarterlyActiveUsers(client: AnalyticsClient, quarterStart: Date, quarterEnd: Date) {
  const users = new Set<string>();
  for (let start = quarterStart; start < quarterEnd; start = new Date(start.getTime() + 30 * DAY_MS)) {
    const end = new Date(Math.min(start.getTime() + 30 * DAY_MS, quarterEnd.getTime()));
    let cursor: string | undefined;
    do {
      const page = await client.fetchEvents({ from: start, to: end, type: "session_start", cursor });
      for (const e of page.events) users.add(e.userId);
      cursor = page.nextCursor ?? undefined;
    } while (cursor);
  }
  return users.size;
}
```

```ts
// jobs/churnSignals.ts
import { AnalyticsClient, AnalyticsEvent, RangeTooLargeError } from "../analytics/client";

export async function cancellationsSince(client: AnalyticsClient, since: Date): Promise<AnalyticsEvent[]> {
  const now = new Date();
  try {
    return await allPages(client, since, now);
  } catch (err) {
    if (!(err instanceof RangeTooLargeError)) throw err;
    const out: AnalyticsEvent[] = [];
    let start = since;
    while (start < now) {
      const end = new Date(Math.min(start.getTime() + err.maxDays * 86_400_000 - 1, now.getTime()));
      out.push(...(await allPages(client, start, end)));
      start = new Date(end.getTime() + 1);
    }
    return out;
  }
}

async function allPages(client: AnalyticsClient, from: Date, to: Date) {
  const out: AnalyticsEvent[] = [];
  let cursor: string | undefined;
  do {
    const page = await client.fetchEvents({ from, to, type: "subscription_cancelled", cursor, pageSize: 1000 });
    out.push(...page.events);
    cursor = page.nextCursor ?? undefined;
  } while (cursor);
  return out;
}
```
