#!/usr/bin/env bash
set -euo pipefail

PROFILES_DIR="${HOME}/.playwright-profiles"
STORAGE_STATE="${PROFILES_DIR}/storage-state.json"
LOGIN_PROFILE="${PROFILES_DIR}/login-profile"
TEMP_MCP_CONFIG=$(mktemp /tmp/playwright-login-mcp-XXXXXX.json)

mkdir -p "$PROFILES_DIR"

cat > "$TEMP_MCP_CONFIG" <<EOF
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--user-data-dir",
        "${LOGIN_PROFILE}"
      ]
    }
  }
}
EOF

trap 'rm -f "$TEMP_MCP_CONFIG"' EXIT

echo "MCP config: ${TEMP_MCP_CONFIG}"
echo "Storage state will be saved to: ${STORAGE_STATE}"
echo ""
echo "Launching kimi with persistent browser..."
echo "Tell kimi which sites to open, log in, then ask kimi to save the storage state."
echo ""
echo "Quick reference — ask kimi to run this after you've logged in:"
echo ""
echo '  Save storage state to '"${STORAGE_STATE}"
echo ""

kimi --yolo --mcp-config-file "$TEMP_MCP_CONFIG"
