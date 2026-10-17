---
type: llm
focus: last_message
---
PASS if the answer identifies that `exportOrdersCsvAcme` and `exportOrdersCsvGlobex` are near-copies of `exportOrdersCsv` (same query, same row building, differing only in delimiter, columns and a filter), dispatched by hard-coded org IDs in `handleExportRequest` (and that the refunds export is yet another copy), AND frames it as a tactical pattern — copy-paste with small modifications instead of generalizing, so every new customer format adds another copy and every fix must be repeated in each copy (and the two incoming customer requests will make it worse) — AND recommends generalizing into one export driven by per-customer configuration/data (e.g. a format spec with columns, delimiter, date format, filters).

FAIL if the duplication is not raised, or is mentioned only as "DRY this up" without the tactical/compounding point or without a generalization that would absorb the next customer formats.
