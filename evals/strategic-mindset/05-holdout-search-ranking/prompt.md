---
max_turns: 8
timeout_seconds: 240
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 2
---
Honest opinion wanted. This module ranks search results on our marketplace. It's been patched pretty much nonstop for a year, mostly under "just get it in before the demo" conditions. My lead's position is that it works, conversion is fine, and we should keep stacking features on it; personalized ranking is next on the roadmap. I'm not so sure. Do we keep going like this or stop and put time in first, and if so how much?

```python
# search/ranking.py
import time

BOOSTED_SELLERS = {1182, 2046, 77}   # TODO remove after summer promo (added June 2025)
DEMO_MODE = False                    # flip on for investor demos


def score(listing, query):
    s = 0.0
    if query.lower() in listing.title.lower():
        s += 10
    s += listing.rating * 2
    s += min(listing.sales, 500) / 50
    if listing.seller_id in BOOSTED_SELLERS:
        s *= 1.5
    return s


def score_v2(listing, query):
    # same as score() plus freshness; mobile only for now
    s = 0.0
    if query.lower() in listing.title.lower():
        s += 10
    s += listing.rating * 2
    s += min(listing.sales, 500) / 50
    age_days = (time.time() - listing.created_at) / 86400
    s += max(0.0, 5 - age_days / 7)
    if listing.seller_id in BOOSTED_SELLERS:
        s *= 1.5
    return s


def score_v2_fixed(listing, query):
    # new listings with 1-2 ratings were shooting to the top, quick fix for the demo
    s = score_v2(listing, query)
    if listing.rating_count < 3:
        s -= listing.rating * 2
    return s


def rank(listings, query, platform="web", user=None):
    if platform in ("ios", "android"):
        scored = [(score_v2_fixed(l, query), l) for l in listings]
    else:
        scored = [(score(l, query), l) for l in listings]
    scored.sort(key=lambda p: -p[0])
    results = [l for _, l in scored]

    if DEMO_MODE:
        results = [l for l in results if l.has_photos] or results

    try:
        hidden = _hidden_sellers_cache()
        if user and user.id in hidden:
            results = [l for l in results if l.seller_id not in hidden[user.id]]
    except Exception:
        pass  # hidden-sellers service is flaky, ignore

    # HACK: category pages send query="" and every title "matches", so sort by sales instead
    if query == "":
        results.sort(key=lambda l: -l.sales)

    return results[:50]
```
