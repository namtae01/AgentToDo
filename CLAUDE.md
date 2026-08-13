# Salesforce Project: AgentToDo

## Stack & Org

- API version: 66.0 (Spring '26) — matches `sfdx-project.json sourceApiVersion`
- Stack: Apex, LWC, Flow, Agentforce (Atlas reasoning), Data Cloud, Einstein Trust Layer
- DX: sf CLI v2 only — never invoke legacy `sfdx` commands
- Note: `sfdx-lwc-jest` in npm scripts is the `@salesforce/sfdx-lwc-jest` Jest package, not the deprecated CLI — ignore hook warnings about it

## Org aliases

- Default target: `s-test`
- Default Dev Hub: `s-test`
- Production: `prod` (deploys gated by `.claude/hooks/sf-prod-guard.sh`)

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
