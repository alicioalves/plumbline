---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I can't come up with a name for this class. It's `SessionHelper` right now, which tells you nothing. I've tried `UserContextManager`, `AccountService`, `CurrentUser`... none of them fit. What should I call it?

```ts
// src/app/SessionHelper.ts
import { api } from "./api";
import { analytics } from "./analytics";
import type { FlagRule, UserProfile } from "./types";

const REFRESH_MARGIN_MS = 60_000;
const LAST_WORKSPACE_KEY = "app.lastWorkspaceId";

export class SessionHelper {
  private accessToken: string | null = null;
  private refreshTimer: ReturnType<typeof setTimeout> | null = null;
  private profile: UserProfile | null = null;
  private flagRules: FlagRule[] = [];

  async start(refreshToken: string): Promise<void> {
    await this.refresh(refreshToken);
    this.profile = await api.get<UserProfile>("/me", this.authHeader());
    this.flagRules = await api.get<FlagRule[]>("/flags", this.authHeader());
    analytics.identify(this.profile.id, { plan: this.profile.plan, orgId: this.profile.orgId });
  }

  private async refresh(refreshToken: string): Promise<void> {
    const res = await api.post<{ accessToken: string; expiresAt: number; refreshToken: string }>(
      "/auth/refresh",
      { refreshToken },
    );
    this.accessToken = res.accessToken;
    if (this.refreshTimer) clearTimeout(this.refreshTimer);
    const delay = Math.max(0, res.expiresAt - Date.now() - REFRESH_MARGIN_MS);
    this.refreshTimer = setTimeout(() => this.refresh(res.refreshToken), delay);
  }

  authHeader(): Record<string, string> {
    return this.accessToken ? { Authorization: `Bearer ${this.accessToken}` } : {};
  }

  isEnabled(flag: string): boolean {
    const rule = this.flagRules.find((r) => r.flag === flag);
    if (!rule || !this.profile) return false;
    if (rule.plans && !rule.plans.includes(this.profile.plan)) return false;
    return rule.rolloutPct >= (hash(this.profile.id + flag) % 100);
  }

  displayName(): string {
    if (!this.profile) return "";
    return this.profile.preferredName || `${this.profile.firstName} ${this.profile.lastName}`.trim();
  }

  initials(): string {
    return this.displayName()
      .split(/\s+/)
      .map((part) => part[0]?.toUpperCase() ?? "")
      .slice(0, 2)
      .join("");
  }

  trackPage(path: string): void {
    analytics.page(path, { userId: this.profile?.id, workspaceId: this.lastWorkspaceId() });
  }

  lastWorkspaceId(): string | null {
    return localStorage.getItem(LAST_WORKSPACE_KEY);
  }

  rememberWorkspace(id: string): void {
    localStorage.setItem(LAST_WORKSPACE_KEY, id);
  }

  stop(): void {
    if (this.refreshTimer) clearTimeout(this.refreshTimer);
    this.accessToken = null;
    this.profile = null;
    this.flagRules = [];
    analytics.reset();
  }
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}
```

It's created once at login and passed around to most of the app.
