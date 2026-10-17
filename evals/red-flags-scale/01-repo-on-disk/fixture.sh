#!/usr/bin/env bash
# Builds a ~2,500-line TypeScript monorepo with git history in the current
# (empty) workspace. The planted design problem: the CLI, HTTP and SDK adapters
# each re-implement the core's vocabulary (channel names, error codes, option
# defaults), and the history shows them changing together. Most of the lines are
# realistic filler (templates, delivery, routes) so reading everything is costly.
set -euo pipefail

git init -q
git config user.name "Dev"
git config user.email "dev@example.com"
commit() { git add -A && git commit -qm "$1" --date="$2"; }

mkdir -p packages/core/src/templates packages/core/src/delivery \
  packages/cli/src/commands packages/http/src/routes packages/sdk/src

cat > package.json <<'EOF'
{ "name": "notify", "private": true, "workspaces": ["packages/*"] }
EOF

cat > packages/core/src/index.ts <<'EOF'
export enum Channel {
  Email = "email",
  Sms = "sms",
  Push = "push",
}

export class NotifyError extends Error {
  constructor(
    public readonly kind: "invalid_recipient" | "rate_limited" | "provider_down" | "template_missing",
    message: string,
  ) {
    super(message);
  }
}

export interface SendOptions {
  channel: Channel;
  priority: "low" | "normal" | "high";
  retries: number;
  ttlSeconds: number;
  dryRun: boolean;
}

export interface Message {
  to: string;
  template: string;
  data: Record<string, unknown>;
}

export { send } from "./send";
EOF

cat > packages/core/src/send.ts <<'EOF'
import { Channel, Message, NotifyError, SendOptions } from "./index";
import { deliverEmail } from "./delivery/email";
import { deliverSms } from "./delivery/sms";
import { deliverPush } from "./delivery/push";
import { render } from "./templates/render";

export async function send(msg: Message, opts: SendOptions): Promise<string> {
  const body = render(msg.template, msg.data);
  if (opts.dryRun) return `dry-run:${opts.channel}:${msg.to}`;
  for (let attempt = 0; ; attempt++) {
    try {
      switch (opts.channel) {
        case Channel.Email:
          return await deliverEmail(msg.to, body, opts.ttlSeconds);
        case Channel.Sms:
          return await deliverSms(msg.to, body, opts.priority);
        case Channel.Push:
          return await deliverPush(msg.to, body, opts.priority);
      }
    } catch (e) {
      if (e instanceof NotifyError && e.kind === "rate_limited" && attempt < opts.retries) continue;
      throw e;
    }
  }
}
EOF

# ---- filler: realistic template and delivery modules -----------------------
filler_template() { # name Cap UPPER
  local n=$1 N=$2 U=$3
  cat <<EOF
// Template helpers for ${n} messages.
export interface ${N}Context {
  locale: string;
  timezone: string;
  user: { id: string; name: string; plan: "free" | "pro" | "team" };
}

const ${U}_SUBJECTS: Record<string, string> = {
  en: "Your ${n} update",
  es: "Tu actualización de ${n}",
  pt: "Sua atualização de ${n}",
  fr: "Votre mise à jour ${n}",
};

export function ${n}Subject(ctx: ${N}Context): string {
  return ${U}_SUBJECTS[ctx.locale] ?? ${U}_SUBJECTS.en;
}

export function ${n}Greeting(ctx: ${N}Context): string {
  const hour = Number(new Intl.DateTimeFormat("en", { hour: "numeric", hour12: false, timeZone: ctx.timezone }).format(new Date()));
  if (hour < 12) return \`Good morning, \${ctx.user.name}\`;
  if (hour < 18) return \`Good afternoon, \${ctx.user.name}\`;
  return \`Good evening, \${ctx.user.name}\`;
}
EOF
  for i in $(seq 1 20); do
    cat <<EOF

export function ${n}Section${i}(ctx: ${N}Context, items: string[]): string {
  const visible = ctx.user.plan === "free" ? items.slice(0, ${i}) : items;
  const lines = visible.map((item, idx) => \`\${idx + 1}. \${item}\`);
  if (visible.length < items.length) {
    lines.push(\`…and \${items.length - visible.length} more on a paid plan\`);
  }
  return [\`## ${N} section ${i}\`, ...lines].join("\\n");
}
EOF
  done
}
for t in billing:Billing:BILLING digest:Digest:DIGEST security:Security:SECURITY \
         onboarding:Onboarding:ONBOARDING invite:Invite:INVITE reminder:Reminder:REMINDER; do
  IFS=: read -r name cap upper <<<"$t"
  filler_template "$name" "$cap" "$upper" > "packages/core/src/templates/$name.ts"
done
cat > packages/core/src/templates/render.ts <<'EOF'
const PLACEHOLDER = /\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/g;

export function render(template: string, data: Record<string, unknown>): string {
  return template.replace(PLACEHOLDER, (_, path: string) => {
    const value = path.split(".").reduce<unknown>((acc, key) => (acc as Record<string, unknown>)?.[key], data);
    return value === undefined ? "" : String(value);
  });
}
EOF

filler_delivery() { # name provider Provider PROVIDER
  local n=$1 p=$2 P=$3 PU=$4
  cat <<EOF
import { NotifyError } from "../index";

const ENDPOINT = process.env.${PU}_URL ?? "https://api.${p}.example/v1";
const API_KEY = process.env.${PU}_KEY ?? "";

interface ${P}Response {
  id: string;
  status: "queued" | "sent" | "failed";
  error?: { code: string; message: string };
}

async function post(path: string, body: unknown): Promise<${P}Response> {
  const res = await fetch(\`\${ENDPOINT}\${path}\`, {
    method: "POST",
    headers: { authorization: \`Bearer \${API_KEY}\`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (res.status === 429) throw new NotifyError("rate_limited", "${p} rate limit");
  if (res.status >= 500) throw new NotifyError("provider_down", \`${p} returned \${res.status}\`);
  return (await res.json()) as ${P}Response;
}

function validateRecipient(to: string): void {
  if (!to || to.length > 320) throw new NotifyError("invalid_recipient", \`bad ${n} recipient: \${to}\`);
}
EOF
  for i in $(seq 1 10); do
    cat <<EOF

export async function ${n}Batch${i}(recipients: string[], body: string): Promise<string[]> {
  const ids: string[] = [];
  for (const chunk of chunked(recipients, ${i}0)) {
    chunk.forEach(validateRecipient);
    const res = await post("/batch", { to: chunk, body, batch: ${i} });
    if (res.status === "failed") throw new NotifyError("provider_down", res.error?.message ?? "batch failed");
    ids.push(res.id);
  }
  return ids;
}
EOF
  done
  cat <<'EOF'

function* chunked<T>(items: T[], size: number): Generator<T[]> {
  for (let i = 0; i < items.length; i += size) yield items.slice(i, i + size);
}
EOF
}
filler_delivery email mailer Mailer MAILER > packages/core/src/delivery/email.ts
filler_delivery sms texter Texter TEXTER > packages/core/src/delivery/sms.ts
filler_delivery push pusher Pusher PUSHER > packages/core/src/delivery/push.ts
for pair in email:Email sms:Sms push:Push; do
  IFS=: read -r f fn <<<"$pair"
  cat >> "packages/core/src/delivery/$f.ts" <<EOF

export async function deliver${fn}(to: string, body: string, _extra: unknown): Promise<string> {
  validateRecipient(to);
  const res = await post("/send", { to, body });
  if (res.status === "failed") throw new NotifyError("provider_down", res.error?.message ?? "send failed");
  return res.id;
}
EOF
done
commit "core: channels, errors, delivery and templates" "2026-03-02T10:00:00"

# ---- adapters: each re-implements the core vocabulary -----------------------
cat > packages/cli/src/vocab.ts <<'EOF'
import { Channel, NotifyError, SendOptions } from "@notify/core";

export function parseChannel(s: string): Channel {
  switch (s.toLowerCase()) {
    case "email":
    case "mail":
      return Channel.Email;
    case "sms":
    case "text":
      return Channel.Sms;
    case "push":
      return Channel.Push;
    default:
      throw new Error(`unknown channel: ${s}`);
  }
}

export function channelName(c: Channel): string {
  return { [Channel.Email]: "email", [Channel.Sms]: "sms", [Channel.Push]: "push" }[c];
}

export function exitCodeFor(e: NotifyError): number {
  switch (e.kind) {
    case "invalid_recipient": return 64;
    case "rate_limited": return 75;
    case "provider_down": return 69;
    case "template_missing": return 66;
  }
}

export function resolveOptions(flags: Partial<SendOptions>): SendOptions {
  return {
    channel: flags.channel ?? Channel.Email,
    priority: flags.priority ?? "normal",
    retries: flags.retries ?? 3,
    ttlSeconds: flags.ttlSeconds ?? 86400,
    dryRun: flags.dryRun ?? false,
  };
}
EOF
cat > packages/cli/src/main.ts <<'EOF'
import { send, NotifyError } from "@notify/core";
import { exitCodeFor, parseChannel, resolveOptions } from "./vocab";

export async function main(argv: string[]): Promise<number> {
  const [to, template, channel = "email", ...rest] = argv;
  const opts = resolveOptions({ channel: parseChannel(channel), dryRun: rest.includes("--dry-run") });
  try {
    console.log(await send({ to, template, data: {} }, opts));
    return 0;
  } catch (e) {
    if (e instanceof NotifyError) {
      console.error(`[${e.kind}] ${e.message}`);
      return exitCodeFor(e);
    }
    throw e;
  }
}
EOF
for pair in list:List status:Status retry:Retry history:History; do
  IFS=: read -r c C <<<"$pair"
  cat > "packages/cli/src/commands/$c.ts" <<EOF
// \`notify $c\` command.
export interface ${C}Args { json: boolean; limit: number; since?: string }

export function parse${C}Args(argv: string[]): ${C}Args {
  const args: ${C}Args = { json: false, limit: 20 };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--json") args.json = true;
    else if (argv[i] === "--limit") args.limit = Number(argv[++i]);
    else if (argv[i] === "--since") args.since = argv[++i];
  }
  return args;
}

export function format${C}(rows: Array<Record<string, string>>, args: ${C}Args): string {
  if (args.json) return JSON.stringify(rows.slice(0, args.limit), null, 2);
  const keys = Object.keys(rows[0] ?? {});
  const widths = keys.map((k) => Math.max(k.length, ...rows.map((r) => (r[k] ?? "").length)));
  const line = (r: Record<string, string>) => keys.map((k, i) => (r[k] ?? "").padEnd(widths[i])).join("  ");
  return [line(Object.fromEntries(keys.map((k) => [k, k]))), ...rows.slice(0, args.limit).map(line)].join("\n");
}
EOF
done
commit "cli: send command and listing commands" "2026-03-09T15:20:00"

cat > packages/http/src/vocab.ts <<'EOF'
import { Channel, NotifyError, SendOptions } from "@notify/core";

export function parseChannel(s: string): Channel | undefined {
  switch (s) {
    case "email": return Channel.Email;
    case "sms": return Channel.Sms;
    case "push": return Channel.Push;
    default: return undefined;
  }
}

export function channelName(c: Channel): string {
  return c === Channel.Email ? "email" : c === Channel.Sms ? "sms" : "push";
}

// Same codes as the CLI's exitCodeFor, mapped to HTTP.
export function statusFor(e: NotifyError): { status: number; code: string } {
  switch (e.kind) {
    case "invalid_recipient": return { status: 422, code: "INVALID_RECIPIENT" };
    case "rate_limited": return { status: 429, code: "RATE_LIMITED" };
    case "provider_down": return { status: 503, code: "PROVIDER_DOWN" };
    case "template_missing": return { status: 404, code: "TEMPLATE_MISSING" };
  }
}

export function resolveOptions(body: Partial<SendOptions>): SendOptions {
  return {
    channel: body.channel ?? Channel.Email,
    priority: body.priority ?? "normal",
    retries: body.retries ?? 3,
    ttlSeconds: body.ttlSeconds ?? 86400,
    dryRun: body.dryRun ?? false,
  };
}
EOF
for pair in send:Send status:Status webhooks:Webhooks health:Health templates:Templates; do
  IFS=: read -r r R <<<"$pair"
  cat > "packages/http/src/routes/$r.ts" <<EOF
import type { IncomingMessage, ServerResponse } from "node:http";

export async function read${R}Body(req: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  for await (const c of req) chunks.push(c as Buffer);
  const raw = Buffer.concat(chunks).toString("utf8");
  return raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
}

export function reply${R}(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "content-type": "application/json", "cache-control": "no-store" });
  res.end(JSON.stringify(body));
}

export function paginate${R}<T>(items: T[], url: URL): { items: T[]; next?: string } {
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 50), 200);
  const offset = Number(url.searchParams.get("offset") ?? 0);
  const page = items.slice(offset, offset + limit);
  const next = offset + limit < items.length ? \`?offset=\${offset + limit}&limit=\${limit}\` : undefined;
  return { items: page, next };
}
EOF
done
commit "http: routes and error mapping" "2026-03-16T11:05:00"

cat > packages/sdk/src/vocab.ts <<'EOF'
import { Channel, NotifyError, SendOptions } from "@notify/core";

export type ChannelName = "email" | "sms" | "push";

export function parseChannel(s: ChannelName): Channel {
  return { email: Channel.Email, sms: Channel.Sms, push: Channel.Push }[s];
}

export function channelName(c: Channel): ChannelName {
  return ({ [Channel.Email]: "email", [Channel.Sms]: "sms", [Channel.Push]: "push" } as const)[c];
}

export function errorCode(e: NotifyError): string {
  return {
    invalid_recipient: "INVALID_RECIPIENT",
    rate_limited: "RATE_LIMITED",
    provider_down: "PROVIDER_DOWN",
    template_missing: "TEMPLATE_MISSING",
  }[e.kind];
}

export function resolveOptions(input: Partial<SendOptions>): SendOptions {
  return {
    channel: input.channel ?? Channel.Email,
    priority: input.priority ?? "normal",
    retries: input.retries ?? 3,
    ttlSeconds: input.ttlSeconds ?? 86400,
    dryRun: input.dryRun ?? false,
  };
}
EOF
cat > packages/sdk/src/client.ts <<'EOF'
import { send, NotifyError } from "@notify/core";
import { ChannelName, errorCode, parseChannel, resolveOptions } from "./vocab";

export class NotifyClient {
  async notify(to: string, template: string, channel: ChannelName = "email") {
    try {
      return { ok: true as const, id: await send({ to, template, data: {} }, resolveOptions({ channel: parseChannel(channel) })) };
    } catch (e) {
      if (e instanceof NotifyError) return { ok: false as const, code: errorCode(e), message: e.message };
      throw e;
    }
  }
}
EOF
commit "sdk: typed client" "2026-03-23T09:40:00"

# ---- history that shows the adapters moving in lockstep ---------------------
# perl -pi instead of sed -i: same behavior on macOS (BSD sed, bash 3.2) and Linux.
ADAPTERS="packages/cli/src/vocab.ts packages/http/src/vocab.ts packages/sdk/src/vocab.ts"
perl -pi -e 's/ttlSeconds \?\? 86400/ttlSeconds ?? 43200/' $ADAPTERS
commit "lower default ttl to 12h everywhere" "2026-04-06T14:00:00"

perl -pi -e 's/^  Push = "push",$/  Push = "push",\n  Slack = "slack",/' packages/core/src/index.ts
perl -pi -e 's/\[Channel\.Push\]: "push"/[Channel.Push]: "push", [Channel.Slack]: "slack"/' $ADAPTERS
perl -pi -e 's/^    case "push":$/    case "slack":\n      return Channel.Slack;\n    case "push":/' packages/cli/src/vocab.ts
perl -pi -e 's/^    case "push": return Channel\.Push;$/    case "push": return Channel.Push;\n    case "slack": return Channel.Slack;/' packages/http/src/vocab.ts
perl -pi -e 's/c === Channel\.Sms \? "sms" : "push"/c === Channel.Sms ? "sms" : c === Channel.Push ? "push" : "slack"/' packages/http/src/vocab.ts
perl -pi -e 's/"email" \| "sms" \| "push";/"email" | "sms" | "push" | "slack";/; s/push: Channel\.Push \}/push: Channel.Push, slack: Channel.Slack }/' packages/sdk/src/vocab.ts
commit "add slack channel" "2026-04-20T16:30:00"

perl -pi -e 's/PROVIDER_DOWN/UPSTREAM_UNAVAILABLE/' packages/http/src/vocab.ts packages/sdk/src/vocab.ts
perl -pi -e 's|case "provider_down": return 69;|case "provider_down": return 69; // keep in sync with http + sdk codes|' packages/cli/src/vocab.ts
commit "rename PROVIDER_DOWN to UPSTREAM_UNAVAILABLE in http and sdk" "2026-05-04T10:10:00"

perl -pi -e 's/priority \?\? "normal"/priority ?? "high"/' $ADAPTERS
commit "default priority high (incident 412)" "2026-05-18T19:45:00"
