---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
ugh, our cart module. it's maybe 60 lines, there's nothing clever in it, and yet every other sprint there's another "checkout total is wrong" ticket. each one gets patched and then a different one shows up. I've stared at this thing and I can't say what's actually wrong with it. what am I not seeing?

```ts
// cart/cart.ts
export interface Line { sku: string; unitCents: number; qty: number }

export class Cart {
  lines: Line[] = [];
  shippingCents = 0;
  couponCode: string | null = null;
  discountCents = 0;
  freeShipping = false;
  subtotalCents = 0;
  taxCents = 0;
  totalCents = 0;

  constructor(private readonly taxRate: number, private readonly coupons: CouponBook) {}

  addItem(sku: string, unitCents: number, qty = 1) {
    const existing = this.lines.find((l) => l.sku === sku);
    if (existing) existing.qty += qty;
    else this.lines.push({ sku, unitCents, qty });
    this.recalcSubtotal();
  }

  removeItem(sku: string) {
    this.lines = this.lines.filter((l) => l.sku !== sku);
  }

  setQty(sku: string, qty: number) {
    const line = this.lines.find((l) => l.sku === sku);
    if (line) line.qty = qty;
    this.recalcSubtotal();
    this.recalcTotal();
  }

  applyCoupon(code: string): boolean {
    const c = this.coupons.lookup(code);
    if (!c) return false;
    this.couponCode = code;
    this.discountCents = c.percent ? Math.round((this.subtotalCents * c.percent) / 100) : c.amountCents;
    this.freeShipping = c.freeShipping;
    return true;
  }

  setShipping(cents: number) {
    this.shippingCents = this.freeShipping ? 0 : cents;
    this.recalcTotal();
  }

  recalcSubtotal() {
    this.subtotalCents = this.lines.reduce((s, l) => s + l.unitCents * l.qty, 0);
  }

  recalcTotal() {
    this.taxCents = Math.round((this.subtotalCents - this.discountCents) * this.taxRate);
    this.totalCents = this.subtotalCents - this.discountCents + this.taxCents + this.shippingCents;
  }
}
```

```ts
// checkout/steps.ts
export function onCouponSubmitted(cart: Cart, code: string) {
  if (!cart.applyCoupon(code)) return showError("That code isn't valid");
  cart.recalcTotal();
}

export function onAddressConfirmed(cart: Cart, quote: ShippingQuote) {
  cart.setShipping(quote.cents);
}

export function onPlaceOrder(cart: Cart) {
  cart.recalcSubtotal();
  cart.recalcTotal();
  return submitOrder({ lines: cart.lines, taxCents: cart.taxCents, totalCents: cart.totalCents });
}
```

```tsx
// cart/CartDrawer.tsx (excerpt)
function onRemove(sku: string) {
  cart.removeItem(sku);
  cart.recalcTotal();
  setTotal(cart.totalCents);
}
```
