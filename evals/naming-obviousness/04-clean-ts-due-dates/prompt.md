---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Can you check the naming and readability here? I want someone new to the billing code to be able to follow it without having to ask me.

```ts
// billing/dueDates.ts

/** A calendar date with no time of day or time zone, e.g. an invoice's issue date. */
export interface CalendarDate {
  year: number;
  month: number; // 1-12
  day: number;
}

/** Payment terms on an invoice: "net 30" is { kind: "calendarDays", days: 30 }. */
export type PaymentTerms =
  | { kind: "calendarDays"; days: number }
  | { kind: "businessDays"; days: number };

/** Public holidays on which payments are not processed. */
export class HolidayCalendar {
  private readonly isoDates: Set<string>;

  constructor(holidays: Iterable<CalendarDate>) {
    this.isoDates = new Set([...holidays].map(toIsoString));
  }

  isHoliday(date: CalendarDate): boolean {
    return this.isoDates.has(toIsoString(date));
  }
}

/**
 * The date payment is due on an invoice issued on issueDate. With calendar-day
 * terms, a due date that lands on a weekend or holiday moves forward to the
 * next business day, as our contracts require.
 */
export function dueDate(issueDate: CalendarDate, terms: PaymentTerms, holidays: HolidayCalendar): CalendarDate {
  switch (terms.kind) {
    case "calendarDays":
      return nextBusinessDayOnOrAfter(addDays(issueDate, terms.days), holidays);
    case "businessDays":
      return addBusinessDays(issueDate, terms.days, holidays);
  }
}

/** Whether an invoice due on dueOn is overdue on today. Payment on the due date itself is on time. */
export function isOverdue(dueOn: CalendarDate, today: CalendarDate): boolean {
  return toIsoString(today) > toIsoString(dueOn); // ISO dates sort correctly as strings
}

function isBusinessDay(date: CalendarDate, holidays: HolidayCalendar): boolean {
  const weekday = toUtcMidnight(date).getUTCDay(); // 0 is Sunday, 6 is Saturday
  return weekday !== 0 && weekday !== 6 && !holidays.isHoliday(date);
}

function nextBusinessDayOnOrAfter(date: CalendarDate, holidays: HolidayCalendar): CalendarDate {
  let candidate = date;
  while (!isBusinessDay(candidate, holidays)) {
    candidate = addDays(candidate, 1);
  }
  return candidate;
}

function addBusinessDays(start: CalendarDate, businessDays: number, holidays: HolidayCalendar): CalendarDate {
  let date = start;
  for (let remaining = businessDays; remaining > 0; ) {
    date = addDays(date, 1);
    if (isBusinessDay(date, holidays)) remaining--;
  }
  return date;
}

function addDays(date: CalendarDate, days: number): CalendarDate {
  const shifted = toUtcMidnight(date);
  shifted.setUTCDate(shifted.getUTCDate() + days);
  return { year: shifted.getUTCFullYear(), month: shifted.getUTCMonth() + 1, day: shifted.getUTCDate() };
}

// Dates are handled as UTC midnight so that no local time zone or DST change can shift the day.
function toUtcMidnight(date: CalendarDate): Date {
  return new Date(Date.UTC(date.year, date.month - 1, date.day));
}

function toIsoString(date: CalendarDate): string {
  const pad = (n: number, width: number) => String(n).padStart(width, "0");
  return `${pad(date.year, 4)}-${pad(date.month, 2)}-${pad(date.day, 2)}`;
}
```
