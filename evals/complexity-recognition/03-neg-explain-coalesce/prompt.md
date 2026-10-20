---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
I'm new to this codebase. Can you walk me through what `coalesceWindows` does, step by step? In particular I don't get what `gapMs` is for or what happens to the labels.

```ts
// scheduling/windows.ts
export interface Window {
  start: number; // epoch ms, inclusive
  end: number; // epoch ms, exclusive
  label: string;
}

export function coalesceWindows(windows: Window[], gapMs = 0): Window[] {
  if (windows.length === 0) return [];

  const sorted = [...windows].sort((a, b) => a.start - b.start || a.end - b.end);
  const out: Window[] = [{ ...sorted[0] }];

  for (let i = 1; i < sorted.length; i++) {
    const cur = sorted[i];
    const last = out[out.length - 1];

    if (cur.start <= last.end + gapMs) {
      last.end = Math.max(last.end, cur.end);
      if (!last.label.split("+").includes(cur.label)) {
        last.label = `${last.label}+${cur.label}`;
      }
    } else {
      out.push({ ...cur });
    }
  }

  return out;
}

export function totalCoveredMs(windows: Window[]): number {
  return coalesceWindows(windows).reduce((sum, w) => sum + (w.end - w.start), 0);
}
```

It's called from the maintenance-calendar view like `coalesceWindows(windows, 15 * 60 * 1000)`.
