---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
We've had three bugs this month that all came from someone misreading this module: billing undercounted seats, an announcement only reached part of a team, and the admin team page did something nobody expected. Nothing in the file is technically broken, people just walk away from it with the wrong idea. Can you see why that keeps happening?

```python
# workspace/members.py
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

IDLE_AFTER = timedelta(minutes=5)


@dataclass
class Member:
    id: int
    org: int
    email: str
    active: bool              # False once the member has been removed from the workspace
    last_seen: datetime | None


def get_members(tenant_id: int, active: bool = True) -> list[Member]:
    rows = db.query("SELECT * FROM members WHERE org_id = %s", tenant_id)
    members = [Member(**r) for r in rows]
    if active:
        now = datetime.now(timezone.utc)
        members = [m for m in members if m.last_seen and now - m.last_seen < IDLE_AFTER]
    return members


def is_active(member: Member) -> bool:
    return member.active


def seat_count(account_id: int) -> int:
    return len([m for m in get_members(account_id, active=False) if m.active])


def deactivate(member: Member) -> None:
    db.execute("UPDATE members SET active = false WHERE id = %s", member.id)


def notify_active(org_id: int, message: str) -> None:
    for m in get_members(org_id):
        mailer.send(m.email, message)
```

```python
# billing/invoice.py
def billable_seats(org_id: int) -> int:
    return len(members.get_members(org_id))


# admin/views.py
def team_page(request, org_id):
    team = members.get_members(org_id)
    return render(request, "team.html", {"team": team, "seats": members.seat_count(org_id)})


# announcements/send.py
def announce(org_id: int, text: str) -> None:
    members.notify_active(org_id, text)
```
