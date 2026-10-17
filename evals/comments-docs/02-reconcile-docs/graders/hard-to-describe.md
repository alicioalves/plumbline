---
type: llm
focus: last_message
---
PASS if the answer treats the long, heavily qualified `Reconcile` comment (chains of "unless", "except when", "in which case") as a signal of a design problem rather than only a writing problem: `Reconcile` mixes several jobs and modes (image rollout, scale up, scale down, dry-run, force) controlled by boolean flags, so it cannot be described simply. The answer must recommend a structural change (e.g. separating planning from applying so dry-run falls out, splitting rollout from scaling, replacing the `dryRun`/`force` booleans) in addition to, or instead of, rewording the comment. FAIL if the answer only suggests tightening, shortening or reformatting the comment (e.g. into a bullet list) with no point that the difficulty of describing it reflects the function's design.
