---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
`OrderQuery.search` started out simple, and now every screen that uses it has added a little something. Is its interface still the right shape for a shared query helper? Here it is with its three callers.

```python
# orders/query.py
from dataclasses import dataclass
from datetime import date

MOBILE_MAX_PAGE = 20


@dataclass
class OrderFilter:
    customer_id: int | None = None
    status: str | None = None
    placed_after: date | None = None
    placed_before: date | None = None


class OrderQuery:
    def __init__(self, db):
        self.db = db

    def search(self, flt, page=1, page_size=50, for_admin_panel=False,
               mobile_client=False, include_line_items_for_export=False):
        clauses, params = [], []
        if flt.customer_id is not None:
            clauses.append("customer_id = ?")
            params.append(flt.customer_id)
        if flt.status:
            clauses.append("status = ?")
            params.append(flt.status)
        if flt.placed_after:
            clauses.append("placed_at >= ?")
            params.append(flt.placed_after)
        if flt.placed_before:
            clauses.append("placed_at < ?")
            params.append(flt.placed_before)
        if not for_admin_panel:
            clauses.append("deleted_at IS NULL")
        if mobile_client:
            page_size = min(page_size, MOBILE_MAX_PAGE)

        where = " AND ".join(clauses) or "1=1"
        rows = self.db.fetch_all(
            f"SELECT * FROM orders WHERE {where} ORDER BY placed_at DESC LIMIT ? OFFSET ?",
            *params, page_size, (page - 1) * page_size,
        )
        if not rows:
            return None

        if include_line_items_for_export:
            ids = [r["id"] for r in rows]
            marks = ",".join("?" * len(ids))
            items = self.db.fetch_all(f"SELECT * FROM line_items WHERE order_id IN ({marks})", *ids)
            by_order = {}
            for item in items:
                by_order.setdefault(item["order_id"], []).append(item)
            for r in rows:
                r["line_items"] = by_order.get(r["id"], [])

        if for_admin_panel:
            for r in rows:
                r["customer_email"] = self.db.fetch_value(
                    "SELECT email FROM customers WHERE id = ?", r["customer_id"]
                )
        return rows
```

```python
# admin/views.py
def admin_orders(request):
    flt = OrderFilter(status=request.GET.get("status"))
    orders = order_query.search(flt, page=int(request.GET.get("page", 1)), for_admin_panel=True)
    if orders is None:
        orders = []
    return render(request, "admin/orders.html", {"orders": orders})
```

```python
# api/mobile.py
def my_orders(user, page):
    orders = order_query.search(OrderFilter(customer_id=user.id), page=page, mobile_client=True)
    if orders is None:
        return {"orders": [], "page": page}
    return {"orders": [serialize_order(o) for o in orders], "page": page}
```

```python
# exports/nightly.py
def export_day(day, writer):
    flt = OrderFilter(placed_after=day, placed_before=day + timedelta(days=1))
    page = 1
    while True:
        rows = order_query.search(flt, page=page, page_size=500, include_line_items_for_export=True)
        if rows is None:
            break
        for r in rows:
            for item in r["line_items"]:
                writer.writerow([r["id"], r["placed_at"], item["sku"], item["qty"], item["price_cents"]])
        page += 1
```
