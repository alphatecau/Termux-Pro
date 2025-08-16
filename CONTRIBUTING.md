# Contributing to Termux-Pro
## Branching & Workflow
- Base branch: `main`. Create feature branches as `feat/<short-name>` or `fix/<short-name>`.
- Keep PRs small and focused; reference issues with `Fixes #123`.

## Commit Standards
- Conventional commits preferred: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Example: `feat(backup): add rotation policy`

## Code Quality
- Bash: `set -Eeuo pipefail`, functions, clear error messages.
- Idempotency: scripts should be safe to re-run.
- No secrets in Git. Use `.env` (ignored) for local secrets.

## Security
- Avoid storing tokens/keys in repo or backups.
- Report vulnerabilities via Issues or email (see SECURITY.md).

## PR Checklist
- [ ] Works in Termux (Android).
- [ ] No hard-coded secrets.
- [ ] Minimal dependencies.
- [ ] Updated docs when behavior changes.
