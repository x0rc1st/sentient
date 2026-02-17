#!/bin/bash
# /tmp/setup-velociraptor.sh
# One-time setup for Velociraptor on Pwnbox

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/animations.sh"

PERSIST_DIR="/opt/htb-monitoring"
VELO_VERSION="v0.75.6"
VELO_RELEASE="https://github.com/Velocidex/velociraptor/releases/download/v0.75"
SYSMON_URL="https://raw.githubusercontent.com/x0rc1st/sentient/main/Sysmon64.exe"
SYSMON_CONFIG_URL="https://raw.githubusercontent.com/x0rc1st/sentient/main/sysmonconfig-excludes-only.xml"
OSQUERY_VERSION="5.21.0"
OSQUERY_ZIP_URL="https://github.com/osquery/osquery/releases/download/${OSQUERY_VERSION}/osquery-${OSQUERY_VERSION}.windows_x86_64.zip"
OSQUERY_CONF_URL="https://raw.githubusercontent.com/x0rc1st/sentient/main/osquery.conf"
OSQUERY_FLAGS_URL="https://raw.githubusercontent.com/x0rc1st/sentient/main/osquery.flags"
REPO_API="https://api.github.com/repos/x0rc1st/sentient/contents/rulesets"
RAW_BASE="https://raw.githubusercontent.com/x0rc1st/sentient/main/rulesets"

show_phase_header "Downloading Sentient Components"

info "Creating directories..."
mkdir -p "$PERSIST_DIR/rulesets"

run_with_spinner "Downloading Velociraptor (Linux)..." \
    curl -L -o "$PERSIST_DIR/velociraptor" \
    "${VELO_RELEASE}/velociraptor-${VELO_VERSION}-linux-amd64"

run_with_spinner "Downloading Velociraptor (Windows)..." \
    curl -L -o "$PERSIST_DIR/velociraptor.exe" \
    "${VELO_RELEASE}/velociraptor-${VELO_VERSION}-windows-amd64.exe"

run_with_spinner "Downloading Sysmon64.exe..." \
    curl -L -o "$PERSIST_DIR/Sysmon64.exe" "$SYSMON_URL"

run_with_spinner "Downloading Sysmon config..." \
    curl -L -o "$PERSIST_DIR/sysmonconfig-excludes-only.xml" "$SYSMON_CONFIG_URL"

run_with_spinner "Downloading osquery ZIP..." \
    curl -L -o "$PERSIST_DIR/osquery.zip" "$OSQUERY_ZIP_URL"

run_with_spinner "Downloading osquery config..." \
    curl -L -o "$PERSIST_DIR/osquery.conf" "$OSQUERY_CONF_URL"

run_with_spinner "Downloading osquery flags..." \
    curl -L -o "$PERSIST_DIR/osquery.flags" "$OSQUERY_FLAGS_URL"

show_phase_header "Downloading Rulesets"

RULESET_FILES=$(curl -s "$REPO_API" | grep '"name"' | grep -v '.gitkeep' | sed 's/.*"name": "\(.*\)".*/\1/')
RULESET_COUNT=$(echo "$RULESET_FILES" | wc -w)
RULESET_IDX=0
for file in $RULESET_FILES; do
    RULESET_IDX=$((RULESET_IDX + 1))
    run_with_spinner "[$RULESET_IDX/$RULESET_COUNT] $file" \
        curl -sL -o "$PERSIST_DIR/rulesets/$file" "$RAW_BASE/$file"
done

info "Setting permissions..."
chmod +x "$PERSIST_DIR/velociraptor"

info "Verifying..."
ls -lah "$PERSIST_DIR/"

echo ""
success "Setup complete. Directory structure:"
find "$PERSIST_DIR" -type f -exec ls -lh {} \;
