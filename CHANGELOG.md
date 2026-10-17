# Changelog

## 1.4.0

### Added

- **Flag 18, Vocabulary Not Owned** in `red-flags`: adapters (bindings, SDKs, clients) that each re-implement names, codes, parsing or defaults the core module should expose. New syndrome cluster in the flag interaction map, **The Adapter Echo** (Vocabulary Not Owned + Repetition + Information Leakage).
- **ACCEPTED state** in `red-flags`: a flag whose signal is present but backed by an explicit, still-valid rationale in the code or docs is listed in one line and left out of the summary and prioritization, instead of being reported as a problem.
- **Reading strategy** in `red-flags` for targets over about 1,000 lines or spanning several packages: public API first, then boundaries, then only the implementations a signal points at; tests and generated code skipped. `design-review` points to it for reviews at scale.
- **Python and TypeScript guides** (`red-flags/references/python.md`, `typescript.md`): the idiomatic shapes each flag takes in those languages.
- **Read-only git access** (`git log`, `git diff`, `git show`) for `red-flags`, `code-evolution`, `information-hiding` and `design-review`. `code-evolution` reviews a branch with `git diff <base>...HEAD`; the Git Co-Change Test now has a concrete command.
- **Eval case `11-rust-bindings`** for `red-flags`, condensed from a real review of a Rust workspace with Node, Python and WASM bindings.
- **Grok Build support.** Install with `grok plugin marketplace add tomymaritano/plumbline` and `grok plugin install plumbline`. Native manifests live in `.grok-plugin/` and are kept in sync by `scripts/bump-version.sh`.

## 1.3.1

First release as Plumbline. 16 skills and the `clean-room-alternative` subagent, installable on Claude Code, skills.sh, Codex, Cursor, OpenCode, Antigravity, Factory Droid, GitHub Copilot CLI, Kimi Code and Pi.
