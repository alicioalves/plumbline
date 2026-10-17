---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We want to start serving AVIF to browsers that support it, and the plan was to put the format in the image URL. I sat down to estimate it and it turns out to be four files across three deployables (the web app, the edge worker, the admin tool), and the worker is owned by another team. How did a URL tweak turn into a cross-team project, and how should this be structured so the next change to image URLs stays in one place?

```ts
// web/src/media/imageUrl.ts
import { createHmac } from "crypto";

const SECRET = process.env.IMG_SIGNING_KEY!;

export function imageUrl(assetId: string, width: number, height: number): string {
  const path = `/img/${width}x${height}/${assetId}.webp`;
  const sig = createHmac("sha256", SECRET).update(path).digest("hex").slice(0, 16);
  return `https://cdn.example.com${path}?s=${sig}`;
}
```

```tsx
// web/src/components/Gallery.tsx (excerpt)
const WIDTHS = [320, 640, 1280];

function srcSet(assetId: string): string {
  return WIDTHS.map((w) => `${imageUrl(assetId, w, Math.round(w * 0.75))} ${w}w`).join(", ");
}

function dimensionsOf(url: string): { width: number; height: number } {
  const m = url.match(/\/img\/(\d+)x(\d+)\//)!;
  return { width: Number(m[1]), height: Number(m[2]) };
}
```

```ts
// edge-worker/src/resize.ts
const ROUTE = /^\/img\/(\d+)x(\d+)\/([a-f0-9]{24})\.webp$/;

export async function handle(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const m = ROUTE.exec(url.pathname);
  if (!m) return new Response("not found", { status: 404 });

  const expected = (await hmacSha256Hex(env.IMG_SIGNING_KEY, url.pathname)).slice(0, 16);
  if (url.searchParams.get("s") !== expected) {
    return new Response("bad signature", { status: 403 });
  }

  const [, w, h, assetId] = m;
  const original = await env.ORIGINALS.get(`${assetId}/original`);
  if (!original) return new Response("not found", { status: 404 });

  const body = await resize(await original.arrayBuffer(), Number(w), Number(h), "webp");
  return new Response(body, {
    headers: { "content-type": "image/webp", "cache-control": "public, max-age=31536000, immutable" },
  });
}
```

```ts
// admin/src/purge.ts
const SIZES = ["320x240", "640x480", "1280x960", "160x120"];

export async function purgeAsset(cdn: CdnClient, assetId: string): Promise<void> {
  await cdn.purge(SIZES.map((s) => `https://cdn.example.com/img/${s}/${assetId}.webp`));
}
```
