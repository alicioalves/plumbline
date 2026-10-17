---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Edit, Write, Skill, "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)", "Bash(git checkout:*)", "Bash(python3 -m unittest:*)"]
model: opus
runs: 3
---
Apply the findings in REPORT.md. The tests run with `python3 -m unittest`. I approve the whole plan up front, including any public-interface changes, so go ahead without stopping to ask.
