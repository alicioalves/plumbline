---
type: llm
focus: last_message
---
PASS if the answer identifies that `PoolConfig` pushes tuning decisions onto every caller that the pool should make itself — both clients pass identical values for all five fields, `min_idle`/`max_size` have an unenforced constraint ("must not exceed"), `validate_on_borrow: false` is a choice few callers would want, and `idle_timeout_ms` / `maintenance_interval_ms` are values callers have no basis for choosing — AND frames this as complexity pushed up to callers rather than absorbed by the module (configuration parameters that don't earn their place, every caller paying for decisions the implementer avoided, or equivalent), AND recommends shrinking the surface: constants or sensible defaults inside the pool (e.g. `Pool::new(addr)` with an optional override for the rare caller), enforcing or removing the conflicting pair, and/or computing values dynamically.

FAIL if the answer only suggests a `Default` impl or builder while keeping all five knobs as equally prominent caller decisions, with no argument that most of them shouldn't be caller-facing, or does not raise the config struct at all.
