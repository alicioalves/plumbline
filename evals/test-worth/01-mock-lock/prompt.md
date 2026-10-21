---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Are these tests locking us in? Don't change anything. Tell me which tests to keep.

```ts
// orders.ts
export class Orders {
  constructor(private readonly cards: CardGateway, private readonly mailer: Mailer) {}

  place(cart: { sku: string; qty: number; priceCents: number }, cardToken: string): { id: string; totalCents: number } {
    const totalCents = cart.qty * cart.priceCents;
    this.cards.charge(cardToken, totalCents);
    const id = `ord_${cart.sku}_${cart.qty}`;
    this.mailer.send(id, totalCents);
    return { id, totalCents };
  }
}

export interface CardGateway {
  charge(token: string, cents: number): void;
}
export interface Mailer {
  send(orderId: string, totalCents: number): void;
}
```

```ts
// orders.test.ts
import { Orders } from "./orders";

test("place charges then emails, in that order", () => {
  const calls: string[] = [];
  const cards = { charge: () => calls.push("charge") };
  const mailer = { send: () => calls.push("send") };
  const orders = new Orders(cards as never, mailer as never);
  orders.place({ sku: "mug", qty: 2, priceCents: 500 }, "tok_1");
  expect(calls).toEqual(["charge", "send"]);
});

test("place talks to the gateway with the token and the line total", () => {
  const charge = jest.fn();
  const orders = new Orders({ charge } as never, { send: () => {} } as never);
  orders.place({ sku: "mug", qty: 2, priceCents: 500 }, "tok_1");
  expect(charge).toHaveBeenCalledWith("tok_1", 1000);
  expect(charge).toHaveBeenCalledTimes(1);
});
```
