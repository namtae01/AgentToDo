# SFAESK.md — Salesforce Agentic Engineering Starter Kit

> **This is a runbook for Claude Code to execute, not a tutorial for humans.**
>
> **Human usage:** Drop this file into an empty project folder. Start Claude Code: `claude`. Say: *"Follow SFAESK.md."*
>
> **Claude usage:** Execute phases sequentially. At each 🛑 CHECKPOINT, stop and request explicit human action. Maintain idempotency — re-running on a partially set-up folder must not error. All file contents are inline; do not invent additional config or search the web for setup steps.

---

## Phase 0a — Using this as a GitHub template (skip if running SFAESK.md fresh)

If you cloned this repo via `gh repo create --template` or "Use this template," the scaffold is already done. **Skip Phases 1–5** and run the rebrand script instead:

```bash
chmod +x .claude/scripts/rebrand.sh
.claude/scripts/rebrand.sh "<PROJECT_NAME>" "<PRIMARY_ORG_ALIAS>" "<DEV_HUB_ALIAS>" "<PROD_ORG_ALIAS>"
# Example: .claude/scripts/rebrand.sh acme-agents acme-dev acme-devhub acme-prod
```

The script:
1. Clones / updates `~/dev/claude-plugins/agentforce-adlc` and captures the current HEAD pin
2. Re-clones `.claude/skills/afv` fresh (not shipped in template to avoid stale files)
3. Substitutes all `__PLACEHOLDER__` tokens in `CLAUDE.md`, `README.md`, `.claude/hooks/sf-prod-guard.sh`, and `sfdx-project.json`

After rebrand completes:
1. `npm install`
2. Authorize orgs (Phase 2 below — still required)
3. `claude` and run Phase 6 (plugin installs — still required)
4. Delete the script: `rm .claude/scripts/rebrand.sh`

---

## Phase 0 — Preflight

Verify tooling. Abort with a clear error if any check fails.

```bash
node --version    # require >= 20
sf --version      # require @salesforce/cli >= 2
git --version     # require any
claude --version  # require any
```

### 0b — Resume detection (run before anything else)

If `CLAUDE.md` already exists, **read it now** to recover the cached values, then use the table below to find the earliest incomplete phase and jump straight to it. Do not repeat completed phases.

| Check command | If true → phase already done |
|---|---|
| `test -f sfdx-project.json` | Phase 1 |
| `sf org list --json \| jq -e '.result.nonScratchOrgs[] \| select(.alias=="<PRIMARY_ORG_ALIAS>" and .connectedStatus=="Connected")' > /dev/null 2>&1` | Phase 2 |
| `test -f .mcp.json` | Phase 3 |
| `test -d ~/dev/claude-plugins/agentforce-adlc && test -d .claude/skills/developing-agentforce` | Phase 4 |
| `test -f .claude/settings.json && test -f .claude/hooks/sf-prod-guard.sh` | Phase 5a–5c |
| `git log --oneline \| grep -q SFAESK` | Phase 5e (initial commit) |
| Check if `README.md` content differs from default Salesforce DX boilerplate (look for "## Org aliases" heading) | Phase 5f (README) |
| `/plugin list` output (ask user to run and confirm) | Phase 6 |

If the working directory has none of these markers, it is a fresh run — proceed from Phase 1. If it is truly empty (no `sfdx-project.json`, no `CLAUDE.md`), confirm with the user before continuing.

Then ask the user for these values and **cache them** for the rest of the runbook:

| Key | Default | Purpose |
|---|---|---|
| `PROJECT_NAME` | current folder name | Used in `CLAUDE.md` header |
| `PRIMARY_ORG_ALIAS` | `dev-sandbox` | Default target org |
| `DEV_HUB_ALIAS` | `prod-devhub` | Default Dev Hub |
| `PROD_ORG_ALIAS` | `prod` | Used by the prod-guard hook |
| `GITHUB_REPO` | (optional) | `org/repo` — for README only |

---

## Phase 1 — SFDX scaffold

`sf project generate` always creates a sub-folder; generate into `_scaffold` then flatten:

```bash
sf project generate -n _scaffold
shopt -s dotglob
mv _scaffold/* .
shopt -u dotglob
rmdir _scaffold
```

Initialize git if not already:

```bash
[ -d .git ] || (git init && git branch -M main)
```

Verify these exist before continuing — if any are missing, abort:
- `sfdx-project.json`
- `force-app/main/default/`
- `config/project-scratch-def.json`
- `package.json`

Fix the project name left by `sf project generate` (it hardcodes `_scaffold`):

```bash
jq --arg name "<PROJECT_NAME>" '.name = $name' sfdx-project.json > sfdx-project.json.tmp \
  && mv sfdx-project.json.tmp sfdx-project.json
```

---

## Phase 2 — Org authorization 🛑 CHECKPOINT

Run `sf org list --json` and parse it. Check whether `PRIMARY_ORG_ALIAS` and `DEV_HUB_ALIAS` are present and `connectedStatus === "Connected"`.

If **both** are present, proceed to Phase 3.

If **either** is missing, STOP and print to the user:

```
Authorize the missing orgs in another terminal, then say "continue":

  sf org login web -a <PRIMARY_ORG_ALIAS> -s   # -s = set as default target org
  sf org login web -a <DEV_HUB_ALIAS> -d       # -d = set as default Dev Hub
```

Wait for the user to confirm. Re-run `sf org list --json` to verify before continuing. Do not proceed until both aliases are authorized and connected.

---

## Phase 3 — MCP servers

Check current state first:

```bash
claude mcp list
```

Add **Salesforce DX** in project scope (writes `.mcp.json` — committed):

```bash
claude mcp add --transport stdio --scope project salesforce-dx -- \
  npx -y @salesforce/mcp \
    --orgs DEFAULT_TARGET_ORG,DEFAULT_TARGET_DEV_HUB \
    --toolsets orgs,metadata,data,users,testing,code-analysis \
    --allow-non-ga-tools
```

Add **GitHub** and **Playwright** in user scope, but only if not already present in the `claude mcp list` output:

```bash
claude mcp add --transport http --scope user github https://api.githubcopilot.com/mcp/
claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest --browser=chrome --isolated
```

Verify `.mcp.json` was created in the project root. Note: GitHub MCP triggers OAuth on first tool call — do not authenticate now.

---

## Phase 4 — Plugin and skill cloning

### Agentforce-ADLC plugin (shared location, outside the project)

```bash
mkdir -p ~/dev/claude-plugins
[ ! -d ~/dev/claude-plugins/agentforce-adlc ] && \
  git clone https://github.com/SalesforceAIResearch/agentforce-adlc.git \
    ~/dev/claude-plugins/agentforce-adlc
```

Capture the pinned commit so `main` updates don't silently break the project:

```bash
ADLC_PIN=$(git -C ~/dev/claude-plugins/agentforce-adlc rev-parse HEAD)
echo "Pinned agentforce-adlc to: $ADLC_PIN"
echo "$ADLC_PIN" > .adlc-pin
```

The pin is written to `.adlc-pin` so Phase 5f can read it even on resume. The file is removed after `README.md` is written.

### afv-library skills (in-project)

Clone into a temp directory, then flatten the inner `skills/` folder directly into `.claude/skills/`. Claude Code looks for skills at `.claude/skills/<name>/SKILL.md` — it does **not** recurse into subdirectories — so the skills must be at the top level.

```bash
mkdir -p .claude/skills
if [ ! -d .claude/skills/developing-agentforce ]; then
  TMP=$(mktemp -d)
  git clone --depth 1 https://github.com/forcedotcom/afv-library.git "$TMP/afv"
  mv "$TMP/afv/skills/"* .claude/skills/
  rm -rf "$TMP"
fi
```

The sentinel `developing-agentforce` is a stable afv skill name — if it already exists at the correct path, the whole block is skipped on re-runs.

---

## Phase 5 — Project files

Write the four files below. Replace `<PLACEHOLDERS>` with cached values from Phase 0.

### 5a. `./CLAUDE.md`

Before writing, derive the API version from `sfdx-project.json` (so it always matches):

```bash
SOURCE_API_VERSION=$(jq -r '.sourceApiVersion' sfdx-project.json)
```

Write `CLAUDE.md`, substituting `<SOURCE_API_VERSION>` with the value above:

```markdown
# Salesforce Project: <PROJECT_NAME>

## Stack & Org
- API version: <SOURCE_API_VERSION> — matches `sfdx-project.json sourceApiVersion`
- Stack: Apex, LWC, Flow, Agentforce (Atlas reasoning), Data Cloud, Einstein Trust Layer
- DX: sf CLI v2 only — never invoke legacy `sfdx` commands
- Note: `sfdx-lwc-jest` in npm scripts is the `@salesforce/sfdx-lwc-jest` Jest package, not the deprecated CLI — ignore hook warnings about it

## Org aliases
- Default target: `<PRIMARY_ORG_ALIAS>`
- Default Dev Hub: `<DEV_HUB_ALIAS>`
- Production: `<PROD_ORG_ALIAS>` (deploys gated by `.claude/hooks/sf-prod-guard.sh`)

## Authoritative commands
- `sf org list` — show authed orgs and connection status
- `sf org create scratch -f config/project-scratch-def.json -a <alias> -d` — create scratch org
- `sf project deploy start -o <alias> --test-level RunLocalTests`
- `sf project deploy start -o <alias> --dry-run --test-level RunLocalTests` — validate without deploying
- `sf project retrieve start -o <alias> -m <metadata>`
- `sf apex test run -o <alias> --test-level RunLocalTests --code-coverage --result-format human -w 30`
- `sf apex run -o <alias> -f scripts/apex/<file>.apex` — anonymous Apex (DX MCP cannot do this)
- `sf data query -o <alias> -q "SELECT ..."` (or use the `run_soql_query` MCP tool)
- `sf agent generate test-spec` / `sf agent test create` / `sf agent test run`
- `npm run lint && npm test` — lint LWC/Aura JS + run Jest unit tests
- `npm run test:unit:coverage` — Jest with coverage report

## Code conventions
- Apex: trigger handler pattern, one trigger per object delegating to a `*TriggerHandler` class
- Bulkification: never SOQL/DML inside loops
- Coverage: 85%+ with assertions in every test method (no naked `Test.startTest`)
- Security: `WITH USER_MODE` on user-data SOQL (preferred since API 56.0; replaces deprecated `WITH SECURITY_ENFORCED`); CRUD/FLS checks before write
- LWC: SLDS only, no inline styles. `@api` props, `@wire` reactive, imperative Apex via `@AuraEnabled(cacheable=true)` for reads
- Flow: prefer Record-Triggered (Before-Save) for same-record updates; Screen Flows for guided UI
- Agentforce: topics scoped narrowly with explicit classification descriptions; Actions are Apex-invocable or Flow-based and never expose unbounded SOQL to the agent

## MCP usage rules
- Read-only tools (`run_soql_query`, `get_username`, `list_all_orgs`) are pre-approved
- `deploy_metadata` and `retrieve_metadata` require explicit user approval
- For anonymous Apex: write the script to `scripts/apex/`, then `Bash(sf apex run -f ...)`
- For DML on records: write Apex or use Data Loader — DX MCP has no DML tools

## Available skills (slash commands)
- `/adlc:developing-agentforce` — design and author Agentforce agents
- `/adlc:testing-agentforce` — run Testing Center batches and adversarial probes
- `/adlc:observing-agentforce` — pull STDM traces and triage production agent failures

## Hard rules (never)
- Never deploy directly to Production without explicit human approval and `--dry-run` first
- Never run `sf data delete` on prod orgs
- Never deploy without scratch-org-validated Apex tests + LWC Jest passing
- Never use legacy `sfdx force:source:deploy` — use `sf project deploy start`
```

### 5b. `./.claude/settings.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Edit(force-app/**)", "Write(force-app/**)",
      "Edit(scripts/**)", "Write(scripts/**)",
      "Bash(sf org list*)", "Bash(sf data query*)", "Bash(sf apex test run*)",
      "Bash(sf project retrieve*)", "Bash(sf agent *)",
      "Bash(npm run *)", "Bash(npm test*)", "Bash(npm install*)",
      "Bash(git status)", "Bash(git diff*)", "Bash(git log*)",
      "Bash(git add*)", "Bash(git commit*)", "Bash(git checkout*)",
      "WebFetch(domain:developer.salesforce.com)",
      "WebFetch(domain:architect.salesforce.com)"
    ],
    "ask": [
      "Bash(sf project deploy *)",
      "Bash(sf data delete *)",
      "Bash(sf org delete *)",
      "Bash(sf apex run *)",
      "Bash(git push*)"
    ],
    "deny": [
      "Read(**/.env*)", "Read(**/secrets/**)", "Read(**/*.key)", "Read(**/*.pem)",
      "Bash(sf org delete --no-prompt *)",
      "Bash(curl *)", "Bash(wget *)"
    ]
  },
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": ".claude/hooks/sf-prod-guard.sh", "timeout": 5000 }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        { "type": "command", "command": "if [[ \"$CLAUDE_TOOL_INPUT_FILE_PATH\" == *.cls || \"$CLAUDE_TOOL_INPUT_FILE_PATH\" == *.trigger ]]; then npx -y prettier-plugin-apex --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\" 2>/dev/null || true; fi" },
        { "type": "command", "command": "if [[ \"$CLAUDE_TOOL_INPUT_FILE_PATH\" == *.js || \"$CLAUDE_TOOL_INPUT_FILE_PATH\" == *.html ]]; then npx eslint --fix \"$CLAUDE_TOOL_INPUT_FILE_PATH\" 2>/dev/null || true; fi" }
      ]
    }]
  }
}
```

### 5c. `./.claude/hooks/sf-prod-guard.sh`

Replace `<PROD_ORG_ALIAS>` with the cached value:

```bash
#!/usr/bin/env bash
# Block destructive sf commands targeting production unless authorized.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

PROD_ALIAS="<PROD_ORG_ALIAS>"

if echo "$CMD" | grep -Eq "sf (project deploy|data delete|org delete)"; then
  if echo "$CMD" | grep -Eq -- "-o $PROD_ALIAS\\b" && [[ "$SF_PROD_DEPLOY_AUTHORIZED" != "1" ]]; then
    echo "🛑 BLOCKED: command targets prod ($PROD_ALIAS). Set SF_PROD_DEPLOY_AUTHORIZED=1 to override." >&2
    exit 2
  fi
fi
exit 0
```

Then:

```bash
mkdir -p .claude/hooks
chmod +x .claude/hooks/sf-prod-guard.sh
```

### 5d. Append to `./.gitignore`

Use `grep -qxF <line> .gitignore || echo <line> >> .gitignore` for each, to stay idempotent:

```
# Claude Code
.claude/settings.local.json
.adlc-pin

# Salesforce
.sf/
.sfdx/
*.log
```

### 5f. `./README.md` (overwrite the Salesforce DX boilerplate created by `sf project generate`)

Read ADLC_PIN from `.adlc-pin` if it exists, otherwise re-derive it:

```bash
ADLC_PIN=$(cat .adlc-pin 2>/dev/null || git -C ~/dev/claude-plugins/agentforce-adlc rev-parse HEAD)
```

Write `README.md`:

```markdown
# <PROJECT_NAME>

Salesforce + Agentforce project bootstrapped via SFAESK.

## Org aliases
- Target: `<PRIMARY_ORG_ALIAS>`
- Dev Hub: `<DEV_HUB_ALIAS>`
- Production: `<PROD_ORG_ALIAS>`

## Pinned tooling
- agentforce-adlc: `<ADLC_PIN>`
- @salesforce/mcp: `latest` (review weekly at https://github.com/forcedotcom/mcp/tree/main/releasenotes)

## Quick start
1. `claude` from this folder.
2. Run `/mcp` to confirm `salesforce-dx`, `github`, `playwright` are connected.
3. Try: *"List authed orgs and SELECT Id, Name FROM Account LIMIT 3 against <PRIMARY_ORG_ALIAS>."*

## Slash commands available
- `/adlc:developing-agentforce` — design and author agents
- `/adlc:testing-agentforce` — run Testing Center batches and adversarial probes
- `/adlc:observing-agentforce` — pull STDM and triage production agent failures

## Hard rules
See `CLAUDE.md` for code conventions and prod-deploy guards.
```

Then remove the temp file:

```bash
rm -f .adlc-pin
```

### 5e. Initial commit

```bash
git add .
git commit -m "Initial SFDX scaffold + Claude Code starter kit (SFAESK)"
```

---

## Phase 6 — Plugin installation 🛑 CHECKPOINT

Plugins require Claude Code slash commands, which Claude **cannot self-invoke**. Print to the user:

```
Run these slash commands in this same Claude session, one at a time.
Confirm each succeeds before running the next:

  /plugin marketplace add anthropics/skills
  /plugin install document-skills@anthropic-agent-skills

  /plugin marketplace add ~/dev/claude-plugins/agentforce-adlc
  /plugin install agentforce-adlc@agentforce-adlc

When all four succeed, type "continue".
```

Wait for explicit confirmation before proceeding to Phase 7.

---

## Phase 7 — Verification

Tell the user to run these and report the output. Do not proceed until each is confirmed:

```
/mcp                  # expect: salesforce-dx, github, playwright (all "connected")
/plugin list          # expect: adlc and document-skills installed
/skills               # expect: afv-library skills + document quartet (pdf, docx, pptx, xlsx)
```

Then run a smoke test against the live org by issuing this in plain prose:

> "Try this prompt to verify the DX MCP works end-to-end:
>
> *List my authed Salesforce orgs and run `SELECT Id, Name FROM Account LIMIT 3` against `<PRIMARY_ORG_ALIAS>`.*
>
> If you see 3 accounts, the kit is fully wired."

GitHub MCP OAuth will fire on first GitHub-tool use — opens a browser tab. Approve scoped to the relevant repos only.

---

## Phase 8 — README seed

Merged into **Phase 5f**. The README is now written and committed as part of the initial scaffold commit, not as a separate step.

---

## Phase 9 — Completion summary

Print to the user a final summary:
- Files created (count + paths, including `README.md`)
- MCP servers registered (3)
- Plugins installed (2)
- Skills available (afv count + Anthropic count)
- Pinned `agentforce-adlc` commit SHA (read from `README.md` if `.adlc-pin` was already cleaned up)
- Manual steps the user completed (org auth in Phase 2, plugin install in Phase 6)
- Recommended next action: *"Try `/adlc:developing-agentforce` to design your first agent, or open a feature branch and start building."*

---

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `claude mcp add` fails with "unknown command" | Old Claude Code | `npm i -g @anthropic-ai/claude-code` |
| `.mcp.json` not created | Wrong scope flag | Use `--scope project` explicitly |
| `sf org list` shows orgs but DX MCP can't see them | `--orgs` flag too narrow | Re-add MCP listing aliases explicitly, or use `ALLOW_ALL_ORGS` (less secure) |
| Hook script doesn't fire | Missing execute bit, or `jq` not installed | `chmod +x` and `brew install jq` |
| `/plugin install` fails for adlc | Plugin support requires Claude Code ≥ 2.0 | Update Claude Code |
| afv-library skills don't show in `/skills` | Skills cloned into wrong nesting depth | Verify SKILL.md at `.claude/skills/<name>/SKILL.md` — skills must be direct children of `.claude/skills/`, not nested under an `afv/` parent. If skills are at `.claude/skills/afv/skills/<name>/`, run: `mv .claude/skills/afv/skills/* .claude/skills/ && rm -rf .claude/skills/afv` |
| Prettier-plugin-apex slow on first save | Cold-cache `npx` install | Acceptable; cached after first run. Or remove from PostToolUse hook |
| GitHub MCP tool calls fail with 401 | OAuth never completed | Trigger any GitHub tool to re-fire the OAuth flow |
| Hook warns "Deprecated SFDX command" when reading `package.json` | False positive — `sfdx-lwc-jest` is an npm package name, not the CLI | Safe to ignore; the note in `CLAUDE.md` explains this |
| `sfdx-project.json` still shows `"name": "_scaffold"` | Phase 1 fixup was skipped | `jq --arg n "<PROJECT_NAME>" '.name = $n' sfdx-project.json > tmp && mv tmp sfdx-project.json` |

---

## Idempotency rules for re-runs

- **Phase 0b** — always run resume detection first; read `CLAUDE.md` to recover cached values
- Phase 1 — skip if `sfdx-project.json` exists
- Phase 3 — `claude mcp list` first, only add servers not already present
- Phase 4 — `[ ! -d ... ]` guard already in commands; re-derive ADLC_PIN from `git rev-parse HEAD` if `.adlc-pin` is gone
- Phase 5 — overwrite `CLAUDE.md`, `.claude/settings.json`, hook script unconditionally; use `grep -qxF` for `.gitignore` lines
- Phase 5f — skip if `README.md` already contains "## Org aliases" heading
- Phase 5e — only commit if `git status --porcelain` reports changes
- Phase 6 — slash commands are user-invoked; Claude does not retry

---

End of SFAESK.md.
