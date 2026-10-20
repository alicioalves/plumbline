---
type: llm
focus: last_message
weight: 1
---
PASS if the answer identifies that `TextIndex` exposes many public methods that each do almost nothing (one-line wrappers over `str.lower`, a regex, a set filter, dict get/add/discard), so its interface is about as large as its implementation and the real work of indexing — the normalize → split → drop stopwords → stem pipeline, storing the text, removing old postings on reindex, intersecting postings for a query — is reassembled by every caller, AND supports this with the consequence visible in the callers: the copies already disagree (the wiki path skips stopword removal while the helpdesk applies it, and `find_pages` does not lowercase the query, so capitalised query words are mangled by the `[a-z0-9]` regex and match nothing), AND frames it as a depth problem (shallow module, interface cost close to implementation cost, callers must know the internal steps, or equivalent), AND recommends a small interface that hides the pipeline and bookkeeping, e.g. `add(doc_id, text)` (replacing any previous version), `remove(doc_id)` and `search(query)`, with tokenization, stemming and posting management private.

FAIL if the answer only suggests adding a convenience `tokenize()` helper while keeping the existing fine-grained methods as the public API, or only discusses local issues (the stemmer's quality, performance, type hints) without the interface-versus-implementation point.
