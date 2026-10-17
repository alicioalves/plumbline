---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Subscriptions in our billing app are split into a repository, a service and the HTTP routes. The layering feels redundant: every change touches all three files. How would you restructure it?

```typescript
// subscriptions/repository.ts
import { Pool } from "pg";

export type SubscriptionStatus = "trialing" | "active" | "past_due" | "canceled";

export interface Subscription {
  id: string;
  customerId: string;
  planId: string;
  status: SubscriptionStatus;
  currentPeriodEnd: Date;
  trialEndsAt: Date | null;
  cancelAtPeriodEnd: boolean;
}

export class SubscriptionRepository {
  constructor(private readonly pool: Pool) {}

  async findById(id: string): Promise<Subscription | null> {
    const { rows } = await this.pool.query("SELECT * FROM subscriptions WHERE id = $1", [id]);
    return rows[0] ? toSubscription(rows[0]) : null;
  }

  async findByCustomer(customerId: string): Promise<Subscription[]> {
    const { rows } = await this.pool.query(
      "SELECT * FROM subscriptions WHERE customer_id = $1 ORDER BY created_at DESC",
      [customerId],
    );
    return rows.map(toSubscription);
  }

  async insert(sub: Omit<Subscription, "id">): Promise<Subscription> {
    const { rows } = await this.pool.query(
      `INSERT INTO subscriptions (customer_id, plan_id, status, current_period_end, trial_ends_at, cancel_at_period_end)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [sub.customerId, sub.planId, sub.status, sub.currentPeriodEnd, sub.trialEndsAt, sub.cancelAtPeriodEnd],
    );
    return toSubscription(rows[0]);
  }

  async updateFields(id: string, fields: Partial<Omit<Subscription, "id">>): Promise<void> {
    const cols = Object.keys(fields).map((k, i) => `${toSnakeCase(k)} = $${i + 2}`);
    await this.pool.query(`UPDATE subscriptions SET ${cols.join(", ")} WHERE id = $1`, [id, ...Object.values(fields)]);
  }
}
// toSubscription / toSnakeCase: row <-> camelCase mapping helpers (omitted)
```

```typescript
// subscriptions/service.ts
import { Subscription, SubscriptionRepository } from "./repository";

export class SubscriptionService {
  constructor(private readonly repo: SubscriptionRepository) {}

  findById(id: string): Promise<Subscription | null> {
    return this.repo.findById(id);
  }

  findByCustomer(customerId: string): Promise<Subscription[]> {
    return this.repo.findByCustomer(customerId);
  }

  insert(sub: Omit<Subscription, "id">): Promise<Subscription> {
    return this.repo.insert(sub);
  }

  updateFields(id: string, fields: Partial<Omit<Subscription, "id">>): Promise<void> {
    return this.repo.updateFields(id, fields);
  }
}
```

```typescript
// subscriptions/routes.ts
import { Router } from "express";
import { PLANS } from "../plans";
import { SubscriptionService } from "./service";

const DAY_MS = 24 * 60 * 60 * 1000;
const addDays = (d: Date, n: number) => new Date(d.getTime() + n * DAY_MS);

export function subscriptionRoutes(service: SubscriptionService): Router {
  const router = Router();

  router.post("/subscriptions", async (req, res) => {
    const { customerId, planId } = req.body;
    const plan = PLANS[planId];
    if (!plan) return res.status(400).json({ error: "unknown plan" });

    const existing = await service.findByCustomer(customerId);
    if (existing.some((s) => s.status !== "canceled")) {
      return res.status(409).json({ error: "customer already has a live subscription" });
    }

    const now = new Date();
    const trialEndsAt = plan.trialDays > 0 ? addDays(now, plan.trialDays) : null;
    const sub = await service.insert({
      customerId,
      planId,
      status: trialEndsAt ? "trialing" : "active",
      currentPeriodEnd: addDays(trialEndsAt ?? now, plan.intervalDays),
      trialEndsAt,
      cancelAtPeriodEnd: false,
    });
    res.status(201).json(sub);
  });

  router.post("/subscriptions/:id/cancel", async (req, res) => {
    const sub = await service.findById(req.params.id);
    if (!sub) return res.status(404).end();
    if (sub.status === "canceled") return res.status(409).json({ error: "already canceled" });

    if (sub.status === "trialing") {
      await service.updateFields(sub.id, { status: "canceled", currentPeriodEnd: new Date() });
    } else {
      await service.updateFields(sub.id, { cancelAtPeriodEnd: true });
    }
    res.json(await service.findById(sub.id));
  });

  return router;
}
```
