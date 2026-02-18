#!/bin/bash
# /opt/htb-monitoring/bootstrap.sh
# Called on every Pwnbox boot

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/animations.sh"

PERSIST_DIR="/opt/htb-monitoring"
WORK_DIR="/tmp/velo"
mkdir -p "$WORK_DIR"

# ─── Phase 1: Config generation & admin setup ────────────────────────────────

show_phase_header "Config Generation & Admin Setup"

# 1. Detect current VPN IP
VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
info "VPN IP: $VPN_IP"

# 2. Generate fresh server + client configs with this IP
run_with_spinner_output "Generating server config..." "$WORK_DIR/server.config.yaml" \
    $PERSIST_DIR/velociraptor config generate --merge '{
  "Client": {
    "server_urls": ["https://'"$VPN_IP"':8000/"],
    "use_self_signed_ssl": true
  },
  "Frontend": {
    "bind_address": "0.0.0.0",
    "bind_port": 8000,
    "hostname": "'"$VPN_IP"'"
  },
  "GUI": {
    "bind_address": "0.0.0.0",
    "bind_port": 8889
  },
  "Datastore": {
    "location": "'"$WORK_DIR"'/datastore",
    "filestore_directory": "'"$WORK_DIR"'/filestore"
  }
}'

# 3. Add admin user with known password
run_with_spinner "Creating admin user..." \
    $PERSIST_DIR/velociraptor --config "$WORK_DIR/server.config.yaml" \
    user add admin admin --role administrator

success "Server config generated and admin user created."

# ─── Phase 2: Artifact selection for client monitoring ───────────────────────

show_phase_header "Select Artifacts for Client Monitoring"

# Discover available rulesets
RULESETS=()
for f in "$PERSIST_DIR/rulesets"/*.yaml; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .yaml)
    RULESETS+=("$name")
done

if [ ${#RULESETS[@]} -eq 0 ]; then
    warn "No rulesets found in $PERSIST_DIR/rulesets/"
    info "Skipping artifact selection."
else
    info "Available artifacts:"
    for i in "${!RULESETS[@]}"; do
        printf "${C_CYAN}    %d)${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$((i+1))" "${RULESETS[$i]}"
    done

    echo ""
    ask "Enter the numbers of the artifacts to monitor (space or comma separated)."
    info "Example: 1 3  or  1,2,3  or  'all' for everything."
    read -rp "    Selection: " SELECTION

    SELECTED=()
    if [[ "$SELECTION" =~ ^[Aa]ll$ ]]; then
        SELECTED=("${RULESETS[@]}")
    else
        # Normalize commas to spaces and iterate
        SELECTION="${SELECTION//,/ }"
        for num in $SELECTION; do
            idx=$((num - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#RULESETS[@]}" ]; then
                SELECTED+=("${RULESETS[$idx]}")
            else
                warn "Invalid selection: $num (skipping)"
            fi
        done
    fi

    if [ ${#SELECTED[@]} -gt 0 ]; then
        echo ""
        info "Adding to default_client_monitoring_artifacts:"
        for artifact in "${SELECTED[@]}"; do
            printf "${C_GREEN}    - %s${C_RESET}\n" "$artifact"
        done

        # Use Python to reliably insert artifacts into the YAML config
        python3 -c "
import sys, re
config_path = sys.argv[1]
artifacts = sys.argv[2:]
with open(config_path) as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'default_client_monitoring_artifacts:' in line:
        # Match indentation of existing entries
        indent = ''
        if i+1 < len(lines):
            m = re.match(r'^(\s*)-', lines[i+1])
            if m:
                indent = m.group(1)
        # Find the end of the list
        j = i + 1
        while j < len(lines) and lines[j].strip().startswith('-'):
            j += 1
        # Insert new artifacts
        for artifact in reversed(artifacts):
            lines.insert(j, f'{indent}- {artifact}\n')
        break
with open(config_path, 'w') as f:
    f.writelines(lines)
" "$WORK_DIR/server.config.yaml" "${SELECTED[@]}"

        echo ""
        success "Server config updated."
    else
        info "No artifacts selected. Continuing with defaults."
    fi
fi

# ─── Phase 2b: Artifact selection for server monitoring ──────────────────────

if [ ${#RULESETS[@]} -gt 0 ]; then
    show_phase_header "Select Artifacts for Server Monitoring"

    ask "Are any of the following artifacts server events?"
    for i in "${!RULESETS[@]}"; do
        printf "${C_CYAN}    %d)${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$((i+1))" "${RULESETS[$i]}"
    done

    echo ""
    ask "Enter the numbers of the server event artifacts (space or comma separated)."
    info "Example: 1 3  or  1,2,3  or  'all' for everything, or 'none' to skip."
    read -rp "    Selection: " SRV_SELECTION

    SRV_SELECTED=()
    if [[ "$SRV_SELECTION" =~ ^[Nn]one$ ]] || [ -z "$SRV_SELECTION" ]; then
        SRV_SELECTED=()
    elif [[ "$SRV_SELECTION" =~ ^[Aa]ll$ ]]; then
        SRV_SELECTED=("${RULESETS[@]}")
    else
        SRV_SELECTION="${SRV_SELECTION//,/ }"
        for num in $SRV_SELECTION; do
            idx=$((num - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#RULESETS[@]}" ]; then
                SRV_SELECTED+=("${RULESETS[$idx]}")
            else
                warn "Invalid selection: $num (skipping)"
            fi
        done
    fi

    if [ ${#SRV_SELECTED[@]} -gt 0 ]; then
        echo ""
        info "Adding to default_server_monitoring_artifacts:"
        for artifact in "${SRV_SELECTED[@]}"; do
            printf "${C_GREEN}    - %s${C_RESET}\n" "$artifact"
        done

        # Use Python to insert server monitoring artifacts into the YAML config
        python3 -c "
import sys, re
config_path = sys.argv[1]
artifacts = sys.argv[2:]
with open(config_path) as f:
    lines = f.readlines()
# Try to find an existing default_server_monitoring_artifacts: key
found = False
for i, line in enumerate(lines):
    if 'default_server_monitoring_artifacts:' in line:
        found = True
        indent = ''
        if i+1 < len(lines):
            m = re.match(r'^(\s*)-', lines[i+1])
            if m:
                indent = m.group(1)
        j = i + 1
        while j < len(lines) and lines[j].strip().startswith('-'):
            j += 1
        for artifact in reversed(artifacts):
            lines.insert(j, f'{indent}- {artifact}\n')
        break
if not found:
    # Insert right after the default_client_monitoring_artifacts list
    insert_at = len(lines)
    key_indent = ''
    item_indent = '- '
    for i, line in enumerate(lines):
        if 'default_client_monitoring_artifacts:' in line:
            # Match the indentation of the key itself
            km = re.match(r'^(\s*)', line)
            if km:
                key_indent = km.group(1)
            if i+1 < len(lines):
                m = re.match(r'^(\s*)-', lines[i+1])
                if m:
                    item_indent = m.group(1) + '- '
            # Find end of the client artifacts list
            j = i + 1
            while j < len(lines) and lines[j].strip().startswith('-'):
                j += 1
            insert_at = j
            break
    new_lines = [f'{key_indent}default_server_monitoring_artifacts:\n']
    for artifact in artifacts:
        new_lines.append(f'{item_indent}{artifact}\n')
    for nl in reversed(new_lines):
        lines.insert(insert_at, nl)
with open(config_path, 'w') as f:
    f.writelines(lines)
" "$WORK_DIR/server.config.yaml" "${SRV_SELECTED[@]}"

        echo ""
        success "Server config updated with server monitoring artifacts."

        # Prompt for webhook URL if any selected artifact is an alert ruleset
        for artifact in "${SRV_SELECTED[@]}"; do
            if [[ "$artifact" == Custom.Server.Alerts* ]]; then
                echo ""
                read -rp "$(printf "${C_YELLOW}  [?]${C_RESET} Enter webhook URL for $artifact: ")" WEBHOOK_URL
                if [ -n "$WEBHOOK_URL" ]; then
                    sed -i "s|https://your.webhook.url|$WEBHOOK_URL|g" \
                        "$PERSIST_DIR/rulesets/$artifact.yaml"
                    success "Updated webhook URL in $artifact"
                else
                    warn "No URL provided, keeping default for $artifact"
                fi
            fi
        done
    else
        info "No server event artifacts selected. Continuing with defaults."
    fi
fi

# ─── Phase 3: Start services ────────────────────────────────────────────────

show_phase_header "Start Services"

read -rp "$(printf "${C_YELLOW}  [?]${C_RESET} Continue to start the Velociraptor server and asset server? (Y/n): ")" CONTINUE
if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
    info "Stopped. Config is at: $WORK_DIR/server.config.yaml"
    info "You can review/edit it and re-run this script."
    exit 0
fi

# 4. Extract the client config from the server config
run_with_spinner_output "Extracting client config..." "$WORK_DIR/client.config.yaml" \
    $PERSIST_DIR/velociraptor config client \
    --config "$WORK_DIR/server.config.yaml"

# 5. Extract API config (for querying the running server without datastore conflicts)
run_with_spinner "Extracting API config..." \
    $PERSIST_DIR/velociraptor config api_client \
    --config "$WORK_DIR/server.config.yaml" \
    --name admin --role administrator \
    "$WORK_DIR/api.config.yaml"

# 6. Start the Velociraptor server
$PERSIST_DIR/velociraptor frontend \
  --config "$WORK_DIR/server.config.yaml" \
  --definitions "$PERSIST_DIR/rulesets" \
  -v > "$WORK_DIR/velociraptor.log" 2>&1 &

success "Velociraptor server running on $VPN_IP:8000"
info "GUI available at https://$VPN_IP:8889 (admin:admin)"
info "Server log: $WORK_DIR/velociraptor.log"

# 6. Serve the client binaries + config for lab VMs to pull
mkdir -p "$WORK_DIR/assets"
cp "$PERSIST_DIR/velociraptor"                "$WORK_DIR/assets/"
cp "$PERSIST_DIR/velociraptor.exe"            "$WORK_DIR/assets/"
cp "$WORK_DIR/client.config.yaml"             "$WORK_DIR/assets/"
cp "$PERSIST_DIR/Sysmon64.exe"                "$WORK_DIR/assets/"
cp "$PERSIST_DIR/sysmonconfig-excludes-only.xml" "$WORK_DIR/assets/"
cp "$PERSIST_DIR/osquery.zip"                 "$WORK_DIR/assets/"
cp "$PERSIST_DIR/osquery.conf"                "$WORK_DIR/assets/"
cp "$PERSIST_DIR/osquery.flags"               "$WORK_DIR/assets/"
cd "$WORK_DIR/assets"
python3 -c "from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer; ThreadingHTTPServer(('0.0.0.0', 8443), SimpleHTTPRequestHandler).serve_forever()" > "$WORK_DIR/asset-server.log" 2>&1 &

success "Asset server on http://$VPN_IP:8443"
info "Asset server log: $WORK_DIR/asset-server.log"

# 7. Start the webhook receiver for desktop notifications
python3 "$SCRIPT_DIR/../webhook_receiver.py" > "$WORK_DIR/webhook-receiver.log" 2>&1 &

success "Webhook receiver on http://127.0.0.1:9000"
info "Webhook receiver log: $WORK_DIR/webhook-receiver.log"
info "Ready to provision lab VMs"
