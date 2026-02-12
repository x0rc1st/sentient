#!/bin/bash
# /tmp/setup-velociraptor.sh
# One-time setup for Velociraptor on Pwnbox

set -e

PERSIST_DIR="/opt/htb-monitoring"
VELO_VERSION="v0.75.6"
VELO_RELEASE="https://github.com/Velocidex/velociraptor/releases/download/v0.75"
SYSMON_URL="https://raw.githubusercontent.com/x0rc1st/sentient/main/Sysmon64.exe"
REPO_API="https://api.github.com/repos/x0rc1st/sentient/contents/rulesets"
RAW_BASE="https://raw.githubusercontent.com/x0rc1st/sentient/main/rulesets"

echo "[*] Creating directories..."
mkdir -p "$PERSIST_DIR/rulesets"

echo "[*] Downloading Linux binary..."
curl -L -o "$PERSIST_DIR/velociraptor" \
  "${VELO_RELEASE}/velociraptor-${VELO_VERSION}-linux-amd64"

echo "[*] Downloading Windows binary..."
curl -L -o "$PERSIST_DIR/velociraptor.exe" \
  "${VELO_RELEASE}/velociraptor-${VELO_VERSION}-windows-amd64.exe"

echo "[*] Downloading Sysmon64.exe..."
curl -L -o "$PERSIST_DIR/Sysmon64.exe" "$SYSMON_URL"

echo "[*] Downloading rulesets..."
RULESET_FILES=$(curl -s "$REPO_API" | grep '"name"' | grep -v '.gitkeep' | sed 's/.*"name": "\(.*\)".*/\1/')
for file in $RULESET_FILES; do
  echo "    -> $file"
  curl -sL -o "$PERSIST_DIR/rulesets/$file" "$RAW_BASE/$file"
done

echo "[*] Setting permissions..."
chmod +x "$PERSIST_DIR/velociraptor"

echo "[*] Verifying..."
ls -lah "$PERSIST_DIR/"

echo ""
echo "[+] Setup complete. Directory structure:"
find "$PERSIST_DIR" -type f -exec ls -lh {} \;

