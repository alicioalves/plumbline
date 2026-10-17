---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Last sprint I split our notification sender into three small classes (a renderer, a channel selector and a dispatcher) so each one does one thing. A teammate says that made it worse and wants it back as one module. Who's right? Code and two call sites below.

```python
# notify/render.py
from string import Template

TEMPLATES = {
    "order_shipped": {
        "subject": "Your order $order_id has shipped",
        "body": "Hi $name, your order $order_id is on its way. Track it here: $tracking_url",
        "sms": "Order $order_id shipped: $tracking_url",
    },
    "password_reset": {
        "subject": "Reset your password",
        "body": "Hi $name, use this link to reset your password: $reset_url",
        "sms": "Your reset link: $reset_url",
    },
}


class TemplateRenderer:
    def render(self, template_id, channel, context):
        tpl = TEMPLATES[template_id]
        if channel == "email":
            return {
                "channel": "email",
                "subject": Template(tpl["subject"]).substitute(context),
                "html": Template(tpl["body"]).substitute(context),
                "to": None,
            }
        if channel == "sms":
            text = Template(tpl["sms"]).substitute(context)
            return {"channel": "sms", "text": text[:160], "to": None}
        raise ValueError(f"unknown channel: {channel}")
```

```python
# notify/channels.py
class ChannelSelector:
    def select(self, user, template_id):
        if template_id == "password_reset" and user.get("phone_verified"):
            return "sms"
        if user.get("email_opt_out"):
            return "sms" if user.get("phone") else None
        return "email"

    def address_for(self, user, channel):
        return user["email"] if channel == "email" else user["phone"]
```

```python
# notify/dispatch.py
class Dispatcher:
    def __init__(self, email_client, sms_client):
        self.email_client = email_client
        self.sms_client = sms_client

    def dispatch(self, payload):
        if payload["to"] is None:
            raise ValueError("payload has no recipient")
        if payload["channel"] == "email":
            self.email_client.send(to=payload["to"], subject=payload["subject"], html=payload["html"])
        elif payload["channel"] == "sms":
            self.sms_client.send(to=payload["to"], body=payload["text"])
        else:
            raise ValueError(f"unknown channel: {payload['channel']}")
```

```python
# orders/shipping.py
def on_order_shipped(order, user, renderer, selector, dispatcher):
    channel = selector.select(user, "order_shipped")
    if channel is None:
        return
    payload = renderer.render("order_shipped", channel, {
        "name": user["name"],
        "order_id": order["id"],
        "tracking_url": order["tracking_url"],
    })
    payload["to"] = selector.address_for(user, channel)
    dispatcher.dispatch(payload)
```

```python
# accounts/reset.py
def send_reset_link(user, reset_url, renderer, selector, dispatcher):
    channel = selector.select(user, "password_reset")
    if channel is None:
        raise RuntimeError(f"user {user['id']} has no reachable channel")
    payload = renderer.render("password_reset", channel, {"name": user["name"], "reset_url": reset_url})
    payload["to"] = selector.address_for(user, channel)
    dispatcher.dispatch(payload)
```
