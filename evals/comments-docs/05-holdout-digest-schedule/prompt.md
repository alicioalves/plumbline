---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
ok so a teammate reviewed this and called my comments "noise", which honestly stung a bit because I went out of my way to document every field and explain every step. This module is moving into our shared notifications package, and the mobile and web teams will call `nextSendTime` from their own schedulers, mostly from the doc popups in their editors without opening the file. Is she right? What would you actually write?

```ts
// digests/schedule.ts
import { DateTime } from "luxon";

/**
 * Digest frequency.
 */
export type Frequency = "daily" | "weekly";

/**
 * Digest preferences.
 */
export interface DigestPrefs {
  /** The frequency. */
  frequency: Frequency;
  /** The hour. */
  hour: number;
  /** The time zone. */
  timeZone: string;
  /** The last sent at date. */
  lastSentAt: Date | null;
}

// the period
const PERIOD = { daily: { days: 1 }, weekly: { weeks: 1 } } as const;
// the min gap
const MIN_GAP_HOURS = { daily: 20, weekly: 6 * 24 } as const;

/**
 * Gets the next send time.
 *
 * @param prefs the prefs
 * @param now the now
 * @returns the next send time
 */
export function nextSendTime(prefs: DigestPrefs, now: Date = new Date()): Date {
  // convert now to the zone
  const local = DateTime.fromJSDate(now, { zone: prefs.timeZone });
  // set the hour
  let next = local.set({ hour: prefs.hour, minute: 0, second: 0, millisecond: 0 });
  // if weekly, set the weekday to 1
  if (prefs.frequency === "weekly") {
    next = next.set({ weekday: 1 });
  }
  // if next is before now, add the period
  if (next <= local) {
    next = next.plus(PERIOD[prefs.frequency]);
  }
  // check last sent at
  if (prefs.lastSentAt) {
    // convert last sent at to the zone
    const last = DateTime.fromJSDate(prefs.lastSentAt, { zone: prefs.timeZone });
    // if the gap is less than the min gap, add the period again
    if (next.diff(last, "hours").hours < MIN_GAP_HOURS[prefs.frequency]) {
      next = next.plus(PERIOD[prefs.frequency]);
    }
  }
  // return the date
  return next.toJSDate();
}

/**
 * Describes the schedule.
 *
 * @param prefs the prefs
 * @returns the description
 */
export function describeSchedule(prefs: DigestPrefs): string {
  // pad the hour
  const hh = String(prefs.hour).padStart(2, "0");
  // build the string
  const day = prefs.frequency === "weekly" ? "Mondays" : "Daily";
  // return it
  return `${day} at ${hh}:00 (${prefs.timeZone})`;
}
```
