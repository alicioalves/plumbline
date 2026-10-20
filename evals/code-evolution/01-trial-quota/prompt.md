---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Can you review this PR before I merge it? It adds free trials: an account can trial any plan, with reduced limits until `trialEndsAt`, and nothing once the trial has expired.

```diff
--- a/src/quota/limits.ts
+++ b/src/quota/limits.ts
@@ -1,24 +1,48 @@
 import { Account } from "../accounts";
 import { usageStore } from "./usage";
 
 export type Resource = "projects" | "seats" | "api_calls" | "storage_gb";
 
 const PLAN_LIMITS: Record<Account["plan"], Record<Resource, number>> = {
   starter: { projects: 3, seats: 5, api_calls: 10_000, storage_gb: 5 },
   growth: { projects: 20, seats: 25, api_calls: 250_000, storage_gb: 100 },
   scale: { projects: 200, seats: 250, api_calls: 5_000_000, storage_gb: 2_000 },
 };
 
-export function limitFor(account: Account, resource: Resource): number {
-  return account.limitOverrides?.[resource] ?? PLAN_LIMITS[account.plan][resource];
+export function limitFor(account: Account, resource: Resource, isTrial = false): number {
+  const base = account.limitOverrides?.[resource] ?? PLAN_LIMITS[account.plan][resource];
+  if (isTrial) {
+    if (resource === "api_calls") return Math.min(base, 1_000);
+    if (resource === "storage_gb") return Math.min(base, 1);
+    return Math.min(base, Math.ceil(base / 4));
+  }
+  return base;
 }
 
-export async function checkQuota(account: Account, resource: Resource, amount = 1): Promise<boolean> {
+export async function checkQuota(
+  account: Account,
+  resource: Resource,
+  amount = 1,
+  isTrial = false,
+): Promise<boolean> {
+  if (isTrial && account.trialEndsAt && account.trialEndsAt < new Date()) {
+    return false;
+  }
   const used = await usageStore.get(account.id, resource);
-  return used + amount <= limitFor(account, resource);
+  return used + amount <= limitFor(account, resource, isTrial);
 }
 
 export async function remainingQuota(account: Account, resource: Resource): Promise<number> {
   const used = await usageStore.get(account.id, resource);
-  return Math.max(0, limitFor(account, resource) - used);
+  let limit = limitFor(account, resource);
+  if (account.trialEndsAt) {
+    if (resource === "api_calls") limit = Math.min(limit, 1_000);
+    else if (resource === "storage_gb") limit = Math.min(limit, 1);
+    else limit = Math.min(limit, Math.ceil(limit / 4));
+    if (account.trialEndsAt < new Date()) limit = 0;
+  }
+  return Math.max(0, limit - used);
 }
--- a/src/api/projects.ts
+++ b/src/api/projects.ts
@@ -18,7 +18,7 @@ export async function createProject(req: Request, res: Response) {
   const account = req.account;
-  if (!(await checkQuota(account, "projects"))) {
+  if (!(await checkQuota(account, "projects", 1, account.trialEndsAt != null))) {
     return res.status(402).json({ error: "project limit reached" });
   }
   const project = await projects.create(account.id, req.body);
--- a/src/api/uploads.ts
+++ b/src/api/uploads.ts
@@ -31,7 +31,7 @@ export async function uploadFile(req: Request, res: Response) {
   const account = req.account;
   const sizeGb = req.file.size / 1e9;
-  if (!(await checkQuota(account, "storage_gb", sizeGb))) {
+  if (!(await checkQuota(account, "storage_gb", sizeGb, !!account.trialEndsAt))) {
     return res.status(402).json({ error: "storage limit reached" });
   }
   await blobStore.put(account.id, req.file);
--- a/src/accounts.ts
+++ b/src/accounts.ts
@@ -9,6 +9,7 @@ export interface Account {
   id: string;
   plan: "starter" | "growth" | "scale";
   limitOverrides?: Partial<Record<Resource, number>>;
+  trialEndsAt?: Date;
   createdAt: Date;
 }
```

`checkQuota` is also called from the seat-invite handler and the API gateway middleware; those files aren't in this PR.
