# Installing Plumbline for Codex (App + CLI)

Codex supports installing Plumbline as a plugin from a marketplace source. This registers the plugin identity (name, description, icon) in addition to all 17 skills, and lets you track updates with `codex plugin marketplace upgrade` instead of manual `git pull`.

The Codex App and Codex CLI share the same `~/.codex/config.toml`, so installing once from the CLI makes Plumbline visible and toggleable in the App's Plugins panel too — there's currently no App-only way to add a third-party marketplace, so the CLI step below is required either way.

## Prerequisites

- Codex CLI ≥ 0.142.0 (`codex --version`) — earlier versions reject root-level plugin sources and will silently skip this marketplace
- Git

## Installation

```bash
codex plugin marketplace add tomymaritano/plumbline
codex plugin add plumbline@plumbline
```

Restart Codex (CLI) or reload the Plugins panel (App) to pick up the install.

If the second command can't find the plugin, confirm the exact marketplace identifier Codex assigned:

```bash
codex plugin marketplace list
```

and use that name in place of the second `plumbline` in `codex plugin add <plugin>@<marketplace>`.

## Verify

```bash
codex plugin list --json
```

Look for `plumbline` in the `installed` array.

## Updating

```bash
codex plugin marketplace upgrade plumbline
codex plugin add plumbline@plumbline
```

The first command refreshes the tracked source to the latest commit; re-running `plugin add` picks up any plugin.json version bump.

## Uninstalling

```bash
codex plugin remove plumbline
codex plugin marketplace remove plumbline
```

## Fallback: manual symlink (Codex CLI < 0.142.0, or skills-only)

If you're on an older Codex CLI, or you only want the 17 `SKILL.md` files without the plugin wrapper, clone the repo and link the skills directory into Codex's native skill-scan path:

```bash
git clone https://github.com/tomymaritano/plumbline.git ~/.codex/plumbline
mkdir -p ~/.agents/skills
ln -s ~/.codex/plumbline/skills ~/.agents/skills/plumbline
```

**Windows (PowerShell):**

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\plumbline" "$env:USERPROFILE\.codex\plumbline\skills"
```

Restart Codex to discover the skills. Verify with:

```bash
ls -la ~/.agents/skills/plumbline
```

Update with:

```bash
cd ~/.codex/plumbline && git pull
```

Skills update instantly through the symlink. Uninstall with:

```bash
rm ~/.agents/skills/plumbline
rm -rf ~/.codex/plumbline
```

## Getting Help

- Report issues: <https://github.com/tomymaritano/plumbline/issues>
