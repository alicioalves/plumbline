---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Every time we add a payment provider we end up touching like six files, and something always gets missed — after we added Adyen, partial refunds were broken for a week and the fees report showed zero fees for a month. Product wants Mollie next. I honestly don't know where to start with this. These are the bits of code that mention providers:

```python
# payments/checkout.py
def start_checkout(order, provider):
    if provider == "stripe":
        intent = stripe_client.create_payment_intent(
            amount=order.total_cents, currency=order.currency, metadata={"order_id": order.id}
        )
        return {"redirect_url": None, "client_token": intent.client_secret}
    elif provider == "paypal":
        resp = paypal_client.create_order(order.total_cents / 100, order.currency, str(order.id))
        approve = next(l["href"] for l in resp["links"] if l["rel"] == "approve")
        return {"redirect_url": approve, "client_token": None}
    elif provider == "adyen":
        session = adyen_client.sessions(
            amount={"value": order.total_cents, "currency": order.currency}, reference=str(order.id)
        )
        return {"redirect_url": None, "client_token": session["sessionData"]}
    raise ValueError(f"unknown provider {provider}")


# payments/refunds.py
def refund(payment, amount_cents):
    if payment.provider == "stripe":
        stripe_client.create_refund(payment.external_id, amount=amount_cents)
    elif payment.provider == "paypal":
        paypal_client.refund_capture(payment.external_id, amount_cents / 100, payment.currency)
    elif payment.provider == "adyen":
        adyen_client.refund(payment.psp_reference, {"value": amount_cents, "currency": payment.currency})
    payment.refunded_cents += amount_cents
    payment.save()


# payments/webhooks.py
STATUS_MAP = {
    ("stripe", "payment_intent.succeeded"): "paid",
    ("stripe", "charge.refunded"): "refunded",
    ("paypal", "PAYMENT.CAPTURE.COMPLETED"): "paid",
    ("paypal", "PAYMENT.CAPTURE.REFUNDED"): "refunded",
    ("adyen", "AUTHORISATION"): "paid",
    ("adyen", "REFUND"): "refunded",
}

def handle(provider, headers, body):
    if provider == "stripe":
        event = stripe_client.verify(body, headers["Stripe-Signature"])
        key, ref = event["type"], event["data"]["object"]["id"]
    elif provider == "paypal":
        event = paypal_client.verify(headers, body)
        key, ref = event["event_type"], event["resource"]["id"]
    else:
        event = adyen_client.verify_hmac(body)
        key, ref = event["eventCode"], event["pspReference"]
    status = STATUS_MAP.get((provider, key))
    if status:
        Payment.objects.filter(provider=provider, external_id=ref).update(status=status)


# reporting/fees.py
def provider_fee_cents(payment):
    if payment.provider == "stripe":
        return round(payment.amount_cents * 0.029) + 30
    if payment.provider == "paypal":
        return round(payment.amount_cents * 0.0349) + 49
    if payment.provider == "adyen":
        return round(payment.amount_cents * 0.026) + 11
    return 0


# payments/models.py (excerpt)
class Payment(models.Model):
    provider = models.CharField(max_length=20, choices=[("stripe", "Stripe"), ("paypal", "PayPal"), ("adyen", "Adyen")])
    external_id = models.CharField(max_length=128)
    psp_reference = models.CharField(max_length=64, blank=True)  # Adyen only
    amount_cents = models.IntegerField()
    refunded_cents = models.IntegerField(default=0)
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=20, default="pending")
```
