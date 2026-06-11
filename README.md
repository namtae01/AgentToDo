# __PROJECT_NAME__

> **First-time use (template):** Run `.claude/scripts/rebrand.sh "<project-name>" "<primary-org>" "<devhub>" "<prod-org>"`, then delete this notice.

Salesforce + Agentforce project bootstrapped via SFAESK.

## Org aliases
- Target: `__PRIMARY_ORG_ALIAS__`
- Dev Hub: `__DEV_HUB_ALIAS__`
- Production: `__PROD_ORG_ALIAS__`

## Pinned tooling
- agentforce-adlc: `__ADLC_PIN__`
- @salesforce/mcp: `latest` (review weekly at https://github.com/forcedotcom/mcp/tree/main/releasenotes)

## Quick start
1. `claude` from this folder.
2. Run `/mcp` to confirm `salesforce-dx`, `github`, `playwright` are connected.
3. Try: *"List authed orgs and SELECT Id, Name FROM Account LIMIT 3 against `__PRIMARY_ORG_ALIAS__`."*

## How this kit works

This project was scaffolded by one of two paths, both producing the same end state:

### `SFAESK.md` — the from-zero runbook
A 9-phase Claude Code runbook that turns an empty folder into a working starter: SFDX scaffold, MCP server registration, plugin/skill cloning, `CLAUDE.md` + hooks + settings authoring, initial commit. Used when starting from scratch with only `SFAESK.md` in hand.

### `.claude/scripts/rebrand.sh` — the fast-path for template clones
A one-shot script that assumes the scaffold + configs already exist (because they're committed in the template repo). It only does what can't be pre-baked into Git:
- Refreshes `~/dev/claude-plugins/agentforce-adlc` and captures the current HEAD pin
- Re-clones `.claude/skills/afv` (excluded from template to avoid shipping stale skills)
- Substitutes `__PLACEHOLDER__` tokens in `CLAUDE.md`, `README.md`, `.claude/hooks/sf-prod-guard.sh`, `sfdx-project.json`

### How they cooperate
`SFAESK.md` Phase 0a is the bridge: when starting from a template clone, it tells you to skip Phases 1–5 and run `rebrand.sh` instead. Both paths then reconverge at:
- **Phase 2** — org authorization (`sf org login web`) — neither automates this
- **Phase 6** — plugin installs (`/plugin install` slash commands) — neither automates this; Claude can't self-invoke slash commands

| Starting state | What to do |
|---|---|
| Empty folder + a copy of `SFAESK.md` | `claude` → *"Follow SFAESK.md"* |
| Just ran `gh repo create --template ae-dev-starter-kit` | `.claude/scripts/rebrand.sh ...` then continue with SFAESK.md Phase 2 + 6 |
| Partially set up (interrupted run) | `claude` → *"Follow SFAESK.md"* — Phase 0b resume detection picks up where you stopped |

After a successful rebrand, `rebrand.sh` is single-use — delete it: `rm .claude/scripts/rebrand.sh`.

## Slash commands available
- `/adlc:developing-agentforce` — design and author agents
- `/adlc:testing-agentforce` — run Testing Center batches and adversarial probes
- `/adlc:observing-agentforce` — pull STDM and triage production agent failures

## Hard rules
See `CLAUDE.md` for code conventions and prod-deploy guards.
