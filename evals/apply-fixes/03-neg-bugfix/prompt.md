---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Edit, Write, Skill, "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)", "Bash(git checkout:*)", "Bash(python3 -m unittest:*)"]
model: opus
runs: 3
---
`signup()` in app.py crashes with `KeyError: 'user'`. Please fix it. Tests run with `python3 -m unittest`.
