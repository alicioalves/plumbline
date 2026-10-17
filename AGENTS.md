# AGENTS.md

Guidance for AI coding agents working in this repository. For what Plumbline is and how to install it, see [README.md](README.md).

## Layout

- `skills/<name>/SKILL.md`: the skills themselves, each with YAML frontmatter (`name`, `description`) and optional `references/` files. This is the product.
- `agents/`: subagent definitions used by skills (e.g. `clean-room-alternative.md` for `design-it-twice`).
- `hooks/`: the opt-in review-on-stop hook (`hooks.json`, Node scripts with no dependencies). Tests live in `tests/hooks/` and run with `npm test`.
- `evals/<skill>/`: `claude plugin eval` suites. Each suite's README explains how to run it and what its graders score.
- `scripts/build-site.mjs` + `scripts/site/`: the docs site, built from `skills/` and the README's "What's Inside" tables and published to GitHub Pages on each release. A skill missing from those tables fails the build (CI runs it).
- Platform manifests: `.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.grok-plugin/`, `.agents/`, `.codex/`, `.gemini/`, `.opencode/`, `gemini-extension.json`, `plugin.json`, `package.json`.

## Writing skills

- Skills translate *A Philosophy of Software Design* into checks an agent can run on real code. New or changed guidance should reinforce that philosophy, not general code-review advice.
- Follow the [`writing-skills`](https://github.com/obra/superpowers/blob/main/skills/writing-skills/SKILL.md) process: write a failing scenario first, then the skill, then verify.
- A skill's `description` decides when it triggers. Changes to a description can change triggering for neighboring skills, so re-run the relevant eval suite.
- Keep `SKILL.md` focused; move long reference material into `references/`.

## Checks

Run before committing:

```bash
scripts/check-skills.sh          # skill and agent frontmatter consistency
scripts/bump-version.sh --check  # every manifest carries the same version
claude plugin validate . --strict
npm test                         # hook tests (node:test)
```

## Conventions

- Commit messages use conventional prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `evals:`.
- Bump versions only with `scripts/bump-version.sh <version>`, never by hand, and record the change in `CHANGELOG.md`.
- Eval runs cost real money (see each suite's README). Don't start one unless asked.
- Every skill has its own suite in `evals/<skill>/` (3 cases, `runs: 2`, about $3 per run). After changing a skill's `description`, re-run its suite and the suites of the skills its "Not for … (use X)" clause names; each suite README lists them under "When to re-run".
- `evals/red-flags-scale/` and `evals/apply-fixes/` need Claude Code's sandbox (Bash, Edit, `--scaffold`). Run them on macOS, Linux or WSL2 with the commands in `evals/MAC.md`.
