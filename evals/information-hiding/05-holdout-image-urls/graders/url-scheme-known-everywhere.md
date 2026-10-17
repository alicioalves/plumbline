---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that the image URL scheme is encoded independently in all four places: `imageUrl` builds it, `Gallery.dimensionsOf` parses the `WxH` segment back out with its own regex, the edge worker re-implements the path pattern, the `.webp` extension, the asset-id format and the signing rule (HMAC-SHA256 over the path, first 16 hex chars, `s` query param), and `purge.ts` rebuilds URLs with its own hard-coded size list that must match what the gallery requests, AND frames it as a design problem: one design decision (the URL format and signing scheme) is known by several modules with no single owner and no interface that declares it (information leakage, shared implicit format / protocol, or equivalent), which is why one URL change touches every deployable, AND recommends making one module own that knowledge, e.g. a shared package that both builds and parses/verifies image URLs (used by the web app and the worker), with purging expressed per asset (asking that module for all variants, or a surrogate key / cache tag / path prefix) rather than callers reconstructing URLs, and callers like the gallery getting dimensions from data rather than parsing URLs.

FAIL if the answer only lists the files to change for AVIF, or recommends only a shared constants file or regex while the build, parse and purge logic stay duplicated in each module.
