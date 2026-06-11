#!/usr/bin/env bash
# Block destructive sf commands targeting production unless authorized.
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

PROD_ALIAS="__PROD_ORG_ALIAS__"

if echo "$CMD" | grep -Eq "sf (project deploy|data delete|org delete)"; then
  if echo "$CMD" | grep -Eq -- "-o $PROD_ALIAS\b" && [[ "$SF_PROD_DEPLOY_AUTHORIZED" != "1" ]]; then
    echo "🛑 BLOCKED: command targets prod ($PROD_ALIAS). Set SF_PROD_DEPLOY_AUTHORIZED=1 to override." >&2
    exit 2
  fi
fi
exit 0
