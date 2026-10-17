---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
The `Coupon` type already has a `percent` variant but `computeTotals` ignores it. Make percent coupons work: `value` is a percentage (15 means 15% off), applied to the subtotal before tax, rounded to whole cents. Show me the updated function.

```ts
// pricing.ts
export type Coupon =
  | { kind: "fixed"; amountCents: number }
  | { kind: "percent"; value: number };

export interface LineItem {
  sku: string;
  unitCents: number;
  qty: number;
}

export interface Cart {
  items: LineItem[];
  coupon?: Coupon;
  region: string;
}

const TAX_RATES: Record<string, number> = { CA: 0.0725, NY: 0.04, TX: 0.0625 };

export function computeTotals(cart: Cart) {
  const subtotal = cart.items.reduce((sum, i) => sum + i.unitCents * i.qty, 0);
  let discount = 0;
  if (cart.coupon?.kind === "fixed") {
    discount = Math.min(cart.coupon.amountCents, subtotal);
  }
  const taxable = subtotal - discount;
  const tax = Math.round(taxable * (TAX_RATES[cart.region] ?? 0));
  return { subtotal, discount, tax, total: taxable + tax };
}
```

```ts
// cart.ts
import { computeTotals, Cart, Coupon, LineItem } from "./pricing";

export class CartController {
  constructor(private cart: Cart) {}

  addItem(item: LineItem) {
    const existing = this.cart.items.find((i) => i.sku === item.sku);
    if (existing) existing.qty += item.qty;
    else this.cart.items.push({ ...item });
  }

  removeItem(sku: string) {
    this.cart.items = this.cart.items.filter((i) => i.sku !== sku);
  }

  applyCoupon(coupon: Coupon) {
    this.cart.coupon = coupon;
  }

  summary() {
    const totals = computeTotals(this.cart);
    const itemCount = this.cart.items.reduce((n, i) => n + i.qty, 0);
    return { itemCount, ...totals, display: `$${(totals.total / 100).toFixed(2)}` };
  }
}
```
