# Design review on pull requests

Plumbline ships a reusable GitHub Actions workflow that runs the `code-evolution` skill on every pull request and leaves **one** comment, only when the change introduces or worsens a boundary problem, a shared root cause, or brings back a finding marked fixed in `.plumbline/findings.md`. For style nits, naming or missing tests it stays silent: a reviewer bot that comments on everything gets ignored within a week.

## Set it up

1. Add an `ANTHROPIC_API_KEY` secret to the repository (Settings → Secrets and variables → Actions).
2. Add a workflow that calls the reusable one, pinned to a release tag:

```yaml
# .github/workflows/design-review.yml
name: Design review
on:
  pull_request:
    types: [opened, synchronize, ready_for_review]
jobs:
  design:
    if: github.event.pull_request.draft == false
    permissions:
      contents: read
      pull-requests: write
    uses: tomymaritano/plumbline/.github/workflows/plumbline-review.yml@v1.7.0
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

Optional inputs: `model` (default `claude-sonnet-5-5`), `max_turns` (default 30), `plumbline_ref` (the marketplace git URL, to point at a fork or mirror). Add `paths:` to the trigger to review only the parts of the repo where design matters.

## Cost

Each review is one Claude Code run over the diff, usually **$0.30–$1** with the default model, more for very large diffs. `max_turns` caps how far a run can go.

## Safety

The content of a pull request is written by whoever opened it, and an AI reviewer reads all of it. The workflow is built so a malicious PR can't turn the reviewer against the repository:

- **`pull_request`, never `pull_request_target`.** PRs from forks run without secrets, and the job skips them explicitly, so a stranger's PR never runs with your API key.
- **Least privilege.** The checkout is read-only and the token can only comment on pull requests. The reviewer can't push, approve, request changes or edit files.
- **Narrow tools.** Claude may read files, run `git diff`/`git log`/`git show` and post a PR comment. It can't run the project's code, install anything or call the network otherwise.
- **Prompt-injection guard.** The prompt tells Claude to treat the diff, title, description and files as data, to ignore any instructions inside them, and to point them out in the comment.
- **No key, no run.** Without the secret, the job prints a notice and finishes green.

To review PRs from forks, have a maintainer re-run the workflow from a branch in the main repository after reading the change. Don't switch to `pull_request_target` to make forks work.
