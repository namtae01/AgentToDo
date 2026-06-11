#!/usr/bin/env bash
# One-shot rebrand script for new projects cloned from the ae-dev-starter-kit template.
# Run once, then delete this file.
set -euo pipefail

if [[ $# -lt 4 ]]; then
  cat <<EOF
Usage: $0 <PROJECT_NAME> <PRIMARY_ORG_ALIAS> <DEV_HUB_ALIAS> <PROD_ORG_ALIAS>
Example: $0 acme-agents acme-dev acme-devhub acme-prod
EOF
  exit 1
fi

PROJECT_NAME="$1"
PRIMARY_ORG_ALIAS="$2"
DEV_HUB_ALIAS="$3"
PROD_ORG_ALIAS="$4"

echo "Rebranding to: $PROJECT_NAME / $PRIMARY_ORG_ALIAS / $DEV_HUB_ALIAS / $PROD_ORG_ALIAS"

# --- Refresh agentforce-adlc plugin (shared across all projects at ~/dev/claude-plugins) ---
mkdir -p ~/dev/claude-plugins
if [ ! -d ~/dev/claude-plugins/agentforce-adlc ]; then
  git clone https://github.com/SalesforceAIResearch/agentforce-adlc.git \
    ~/dev/claude-plugins/agentforce-adlc
fi
ADLC_PIN=$(git -C ~/dev/claude-plugins/agentforce-adlc rev-parse HEAD)
echo "Pinned agentforce-adlc to: $ADLC_PIN"

# --- Refresh afv-library skills snapshot (not shipped in template to avoid stale files) ---
rm -rf .claude/skills/afv
git clone --depth 1 https://github.com/forcedotcom/afv-library.git .claude/skills/afv
rm -rf .claude/skills/afv/.git
echo "afv-library skills refreshed."

# --- Substitute placeholders in project files ---
# sed -i.bak works on both macOS (BSD) and Linux (GNU) sed
FILES=(CLAUDE.md README.md .claude/hooks/sf-prod-guard.sh sfdx-project.json)
for f in "${FILES[@]}"; do
  sed -i.bak \
    -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
    -e "s|__PRIMARY_ORG_ALIAS__|$PRIMARY_ORG_ALIAS|g" \
    -e "s|__DEV_HUB_ALIAS__|$DEV_HUB_ALIAS|g" \
    -e "s|__PROD_ORG_ALIAS__|$PROD_ORG_ALIAS|g" \
    -e "s|__ADLC_PIN__|$ADLC_PIN|g" \
    "$f"
  rm -f "${f}.bak"
done

# --- Verify no placeholders remain ---
LEFTOVER=$(grep -rlE \
  "__PROJECT_NAME__|__PRIMARY_ORG_ALIAS__|__DEV_HUB_ALIAS__|__PROD_ORG_ALIAS__|__ADLC_PIN__" \
  CLAUDE.md README.md .claude/hooks/sf-prod-guard.sh sfdx-project.json 2>/dev/null || true)

if [[ -n "$LEFTOVER" ]]; then
  echo "ERROR: leftover placeholders found in: $LEFTOVER"
  exit 1
fi

echo ""
echo "Rebrand complete."
echo ""
echo "Next steps:"
echo "  1. npm install"
echo "  2. sf org login web -a $PRIMARY_ORG_ALIAS -s"
echo "  3. sf org login web -a $DEV_HUB_ALIAS -d"
echo "  4. claude  (then run /plugin install steps from SFAESK.md Phase 6)"
echo "  5. rm $0"
