#!/usr/bin/env bash
# Block destructive sf commands targeting production unless authorized.
# Uses node (a Phase 0 prerequisite) rather than jq, which is not installed on Windows by default.
INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{process.stdout.write(String(JSON.parse(d).tool_input?.command??""))}catch{}})')

PROD_ALIAS="prod"

if echo "$CMD" | grep -Eq "sf (project deploy|data delete|org delete)"; then
  if echo "$CMD" | grep -Eq -- "(-o|--target-org)[= ]$PROD_ALIAS\b" && [[ "$SF_PROD_DEPLOY_AUTHORIZED" != "1" ]]; then
    echo "🛑 BLOCKED: command targets prod ($PROD_ALIAS). Set SF_PROD_DEPLOY_AUTHORIZED=1 to override." >&2
    exit 2
  fi
fi
exit 0
