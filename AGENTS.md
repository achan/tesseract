# AGENTS.md

## Git

- Do not perform git write operations unless the user explicitly asks for them.
  This includes commits, branch creation or renaming, pushes, rebases, merges,
  cherry-picks, and PR creation.
- When committing, do NOT add a `Co-Authored-By` line. Commit as the configured
  git user directly.
- Always commit in logical commits. Each commit should represent one coherent
  change - don't bundle unrelated changes together, and don't split a single
  logical change across multiple commits.
- Format commit messages for GitHub markdown rendering:
  - First line: short summary under 72 characters
  - Blank line after summary
  - Body uses GitHub-flavored markdown (bullet lists, backticks for code/files,
    etc.)
  - Wrap body lines at 72 characters

## Pull Requests

- PR body does not need to wrap lines at 72 characters (unlike commit messages).
- PR body template:

```markdown
## Summary
<What was wrong and how it was fixed>

## Changes
<List of files changed and why>

## Confidence
<high | medium | low> - <brief rationale>
```
