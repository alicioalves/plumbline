---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
`parseDuration("90s")` works, but `parseDuration("1h30m")` throws `InvalidDurationError`. Make it accept compound durations like `1h30m` and `2m30s500ms` by summing the parts. Anything that isn't a sequence of number-plus-unit parts should still throw `InvalidDurationError`. Show me the updated function.

```typescript
// config/duration.ts
export class EmptyDurationError extends Error {
  constructor() {
    super("duration is empty");
  }
}

export class NegativeDurationError extends Error {
  constructor(public readonly input: string) {
    super(`duration must not be negative: ${input}`);
  }
}

export class InvalidDurationError extends Error {
  constructor(public readonly input: string) {
    super(`invalid duration: ${input}`);
  }
}

export class DurationOverflowError extends Error {
  constructor(public readonly input: string) {
    super(`duration too large: ${input}`);
  }
}

const UNIT_MS: Record<string, number> = {
  ms: 1,
  s: 1_000,
  m: 60_000,
  h: 3_600_000,
  d: 86_400_000,
};

/** Parses "250ms", "90s", "5m", "2h" or "1d" into milliseconds. */
export function parseDuration(input: string): number {
  if (input == null) throw new EmptyDurationError();
  const text = input.trim();
  if (text === "") throw new EmptyDurationError();
  if (text.startsWith("-")) throw new NegativeDurationError(text);

  const match = /^(\d+(?:\.\d+)?)(ms|s|m|h|d)$/.exec(text);
  if (!match) throw new InvalidDurationError(text);

  const ms = Math.round(Number(match[1]) * UNIT_MS[match[2]]);
  if (!Number.isSafeInteger(ms)) throw new DurationOverflowError(text);
  return ms;
}
```

```typescript
// config/load.ts (excerpt)
function readTimeout(raw: string | undefined, fallbackMs: number): number {
  try {
    return parseDuration(raw ?? "");
  } catch (err) {
    if (err instanceof EmptyDurationError) return fallbackMs;
    if (err instanceof NegativeDurationError) throw new ConfigError(`timeout cannot be negative: ${raw}`);
    if (err instanceof InvalidDurationError) throw new ConfigError(`bad timeout: ${raw}`);
    if (err instanceof DurationOverflowError) throw new ConfigError(`timeout too large: ${raw}`);
    throw err;
  }
}
```
