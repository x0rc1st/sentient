#!/bin/bash
# /opt/htb-monitoring/bootstrap.sh
# Called on every Pwnbox boot

PERSIST_DIR="/opt/htb-monitoring"
WORK_DIR="/tmp/velo"
mkdir -p "$WORK_DIR"

# ─── Phase 1: Config generation & admin setup ────────────────────────────────

# 1. Detect current VPN IP
VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "[*] VPN IP: $VPN_IP"

# 2. Generate fresh server + client configs with this IP
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
}' > "$WORK_DIR/server.config.yaml"

# 3. Add admin user with known password
$PERSIST_DIR/velociraptor --config "$WORK_DIR/server.config.yaml" \
  user add admin admin --role administrator

echo ""
echo "[+] Server config generated and admin user created."

# ─── Phase 2: Artifact selection for client monitoring ───────────────────────

echo ""
echo "────────────────────────────────────────────────────"
echo " Select artifacts for default client monitoring"
echo "────────────────────────────────────────────────────"
echo ""

# Discover available rulesets
RULESETS=()
for f in "$PERSIST_DIR/rulesets"/*.yaml; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .yaml)
    RULESETS+=("$name")
done

if [ ${#RULESETS[@]} -eq 0 ]; then
    echo "[!] No rulesets found in $PERSIST_DIR/rulesets/"
    echo "[*] Skipping artifact selection."
else
    echo "[*] Available artifacts:"
    for i in "${!RULESETS[@]}"; do
        echo "    $((i+1))) ${RULESETS[$i]}"
    done

    echo ""
    echo "[?] Enter the numbers of the artifacts to monitor (space or comma separated)."
    echo "    Example: 1 3  or  1,2,3  or  'all' for everything."
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
                echo "[!] Invalid selection: $num (skipping)"
            fi
        done
    fi

    if [ ${#SELECTED[@]} -gt 0 ]; then
        echo ""
        echo "[*] Adding to default_client_monitoring_artifacts:"
        for artifact in "${SELECTED[@]}"; do
            echo "    - $artifact"
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
        echo "[+] Server config updated."
    else
        echo "[*] No artifacts selected. Continuing with defaults."
    fi
fi

# ─── Phase 3: Start services ────────────────────────────────────────────────

echo ""
read -rp "[?] Continue to start the Velociraptor server and asset server? (Y/n): " CONTINUE
if [[ "$CONTINUE" =~ ^[Nn]$ ]]; then
    echo "[*] Stopped. Config is at: $WORK_DIR/server.config.yaml"
    echo "[*] You can review/edit it and re-run this script."
    exit 0
fi

# 4. Extract the client config from the server config
$PERSIST_DIR/velociraptor config client \
  --config "$WORK_DIR/server.config.yaml" \
  > "$WORK_DIR/client.config.yaml"

# 5. Start the Velociraptor server
$PERSIST_DIR/velociraptor frontend \
  --config "$WORK_DIR/server.config.yaml" \
  --definitions "$PERSIST_DIR/rulesets" \
  -v > "$WORK_DIR/velociraptor.log" 2>&1 &

echo "[*] Velociraptor server running on $VPN_IP:8000"
echo "[*] GUI available at https://$VPN_IP:8889 (admin:admin)"
echo "[*] Server log: $WORK_DIR/velociraptor.log"

# 6. Serve the client binaries + config for lab VMs to pull
mkdir -p "$WORK_DIR/assets"
cp "$PERSIST_DIR/velociraptor"        "$WORK_DIR/assets/"
cp "$PERSIST_DIR/velociraptor.exe"    "$WORK_DIR/assets/"
cp "$WORK_DIR/client.config.yaml"     "$WORK_DIR/assets/"
cd "$WORK_DIR/assets"
python3 -m http.server 8443 --bind 0.0.0.0 > "$WORK_DIR/asset-server.log" 2>&1 &

echo "[*] Asset server on http://$VPN_IP:8443"
echo "[*] Asset server log: $WORK_DIR/asset-server.log"
echo "[*] Ready to provision lab VMs"
