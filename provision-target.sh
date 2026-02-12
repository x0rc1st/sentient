#!/bin/bash
# /opt/htb-monitoring/provision_target.sh
# Usage: ./provision-target.sh <target_ip> <exercise_id> [windows|linux] [creds]
# Example: ./provision-target.sh 10.129.2.174 test_cmd windows 'htb-student:Academy_student_AD!'

TARGET_IP="$1"
EXERCISE_ID="$2"
OS_TYPE="${3:-windows}"
CREDS="${4:-Administrator:password}"

VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PERSIST_DIR="/opt/htb-monitoring"
WORK_DIR="/tmp/velo"
VELO_CONFIG="$WORK_DIR/server.config.yaml"

if [ -z "$TARGET_IP" ] || [ -z "$EXERCISE_ID" ]; then
    echo "Usage: $0 <target_ip> <exercise_id> [windows|linux] [user:pass]"
    exit 1
fi

echo "[*] Pwnbox IP: $VPN_IP"
echo "[*] Target: $TARGET_IP ($OS_TYPE)"
echo "[*] Exercise: $EXERCISE_ID"

if [ "$OS_TYPE" = "windows" ]; then

    echo "[*] Deploying to Windows via psexec..."
    impacket-psexec "${CREDS}@${TARGET_IP}" \
      "powershell -c \"
        Stop-Service Velociraptor -ErrorAction SilentlyContinue;
        mkdir C:\\ProgramData\\svc -Force | Out-Null;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/velociraptor.exe -OutFile C:\\ProgramData\\svc\\svc.exe;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/client.config.yaml -OutFile C:\\ProgramData\\svc\\c.yaml;
        Start-Process -FilePath C:\\ProgramData\\svc\\svc.exe -ArgumentList 'service install --config C:\\ProgramData\\svc\\c.yaml' -Wait;
        Start-Service Velociraptor;
        Get-Service Velociraptor | Select-Object Status,Name
      \""

else

    echo "[*] Deploying to Linux via SSH..."
    ssh -o StrictHostKeyChecking=no root@"$TARGET_IP" bash -s <<REMOTE
        pkill -f velociraptor || true
        mkdir -p /opt/svc
        curl -s http://${VPN_IP}:8443/velociraptor -o /opt/svc/svc
        curl -s http://${VPN_IP}:8443/client.config.yaml -o /opt/svc/c.yaml
        chmod +x /opt/svc/svc
        /opt/svc/svc --config /opt/svc/c.yaml client -d
        pgrep -a svc
REMOTE

fi

echo "[*] Waiting for enrollment..."
sleep 10

# Find the newly enrolled client
CLIENT_ID=$($PERSIST_DIR/velociraptor \
  --config "$VELO_CONFIG" \
  query "SELECT client_id FROM clients() WHERE last_ip =~ '${TARGET_IP}' ORDER BY last_seen_at DESC LIMIT 1" \
  --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['client_id'] if d else '')" 2>/dev/null)

if [ -z "$CLIENT_ID" ]; then
    echo "[-] Client not found. Check server logs."
    exit 1
fi

echo "[+] Client enrolled: $CLIENT_ID"

# Label it
$PERSIST_DIR/velociraptor --config "$VELO_CONFIG" \
  query "SELECT label(client_id='${CLIENT_ID}', labels=['exercise:${EXERCISE_ID}'], op='set') FROM scope()" 2>/dev/null

# Apply exercise ruleset
RULESET="$PERSIST_DIR/rulesets/${EXERCISE_ID}.yaml"
if [ -f "$RULESET" ]; then
    echo "[*] Uploading ruleset: $RULESET"

    # Upload the artifact
    $PERSIST_DIR/velociraptor --config "$VELO_CONFIG" \
      artifact upload "$RULESET" 2>/dev/null

    # Extract artifact name from YAML
    ARTIFACT_NAME=$(grep '^name:' "$RULESET" | awk '{print $2}')

    # Add to client event monitoring
    $PERSIST_DIR/velociraptor --config "$VELO_CONFIG" \
      query "SELECT add_client_monitoring(artifact='${ARTIFACT_NAME}') FROM scope()" 2>/dev/null

    echo "[+] Monitoring active: $ARTIFACT_NAME"
else
    echo "[!] No ruleset found at $RULESET"
fi

echo ""
echo "[+] Done. Check GUI at https://$VPN_IP:8889"
