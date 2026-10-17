---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Something about money.ts bugs me but I can't say what. I don't even know what kind of review it needs. Can you work out what the problem is, if there is one?

```ts
// money.ts
const MINOR_DIGITS = { USD: 2, EUR: 2, GBP: 2, JPY: 0 } as const;

export type Currency = keyof typeof MINOR_DIGITS;

/**
 * An amount of money in one currency, held as a whole number of minor units
 * (cents for USD, yen for JPY) so that arithmetic never rounds.
 */
export class Money {
  private constructor(
    /** The amount in minor units, for payment APIs that take it in that form. */
    readonly minorUnits: bigint,
    readonly currency: Currency,
  ) {}

  /** Parses a decimal amount like "12.30" or "-5". Throws if it has more decimals than the currency allows. */
  static parse(amount: string, currency: Currency): Money {
    const digits = MINOR_DIGITS[currency];
    const match = /^(-)?(\d+)(?:\.(\d+))?$/.exec(amount);
    if (!match || (match[3]?.length ?? 0) > digits) {
      throw new RangeError(`not a valid ${currency} amount: "${amount}"`);
    }
    const [, sign, whole, fraction = ""] = match;
    const units = BigInt(whole + fraction.padEnd(digits, "0"));
    return new Money(sign ? -units : units, currency);
  }

  static zero(currency: Currency): Money {
    return new Money(0n, currency);
  }

  plus(other: Money): Money {
    return new Money(this.minorUnits + this.sameCurrency(other).minorUnits, this.currency);
  }

  minus(other: Money): Money {
    return new Money(this.minorUnits - this.sameCurrency(other).minorUnits, this.currency);
  }

  equals(other: Money): boolean {
    return this.currency === other.currency && this.minorUnits === other.minorUnits;
  }

  /**
   * Splits this amount in proportion to weights without losing a cent: the
   * parts always sum to exactly this amount. Minor units left over by rounding
   * go one each to the earliest parts with a non-zero weight, so $1.00
   * allocated [1, 1, 1] is 34¢, 33¢, 33¢.
   */
  allocate(weights: readonly number[]): Money[] {
    if (weights.some((w) => !Number.isInteger(w) || w < 0) || !weights.some((w) => w > 0)) {
      throw new RangeError("weights must be non-negative integers, at least one positive");
    }
    const total = weights.reduce((sum, w) => sum + BigInt(w), 0n);
    const parts = weights.map((w) => (this.minorUnits * BigInt(w)) / total);
    const step = this.minorUnits < 0n ? -1n : 1n;
    let leftover = this.minorUnits - parts.reduce((sum, p) => sum + p, 0n);
    for (let i = 0; leftover !== 0n; i++) {
      if (weights[i] === 0) continue;
      parts[i] += step;
      leftover -= step;
    }
    return parts.map((p) => new Money(p, this.currency));
  }

  /** Formats for display, e.g. "$1,234.50" in en-US or "1.234,50 €" in de-DE. */
  format(locale: string): string {
    const major = Number(this.minorUnits) / 10 ** MINOR_DIGITS[this.currency];
    return new Intl.NumberFormat(locale, { style: "currency", currency: this.currency }).format(major);
  }

  private sameCurrency(other: Money): Money {
    if (other.currency !== this.currency) {
      throw new TypeError(`cannot combine ${this.currency} with ${other.currency}`);
    }
    return other;
  }
}
```
