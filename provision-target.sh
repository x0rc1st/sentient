#!/bin/bash
# /opt/htb-monitoring/provision_target.sh
# Usage: ./provision-target.sh <target_ip> [windows|linux] [creds]
# Example: ./provision-target.sh 10.129.2.174 windows 'htb-student:Academy_student_AD!'

TARGET_IP="$1"
OS_TYPE="${2:-windows}"
CREDS="${3:-Administrator:password}"

VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PERSIST_DIR="/opt/htb-monitoring"
WORK_DIR="/tmp/velo"
VELO_CONFIG="$WORK_DIR/server.config.yaml"

if [ -z "$TARGET_IP" ]; then
    echo "Usage: $0 <target_ip> [windows|linux] [user:pass]"
    exit 1
fi

echo "[*] Pwnbox IP: $VPN_IP"
echo "[*] Target: $TARGET_IP ($OS_TYPE)"

if [ "$OS_TYPE" = "windows" ]; then

    echo "[*] Deploying Sysmon to Windows via psexec..."
    impacket-psexec "${CREDS}@${TARGET_IP}" \
      "powershell -c \"
        mkdir C:\\ProgramData\\svc -Force | Out-Null;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/Sysmon64.exe -OutFile C:\\ProgramData\\svc\\Sysmon64.exe;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/sysmonconfig-excludes-only.xml -OutFile C:\\ProgramData\\svc\\sysmonconfig.xml;
        Start-Process -FilePath C:\\ProgramData\\svc\\Sysmon64.exe -ArgumentList '-u force' -Wait -ErrorAction SilentlyContinue;
        Start-Process -FilePath C:\\ProgramData\\svc\\Sysmon64.exe -ArgumentList '-accepteula -i C:\\ProgramData\\svc\\sysmonconfig.xml' -Wait;
        Get-Service Sysmon64 -ErrorAction SilentlyContinue | Select-Object Status,Name
      \""

    echo "[*] Deploying osquery to Windows via psexec..."
    impacket-psexec "${CREDS}@${TARGET_IP}" \
      "powershell -c \"
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/osquery.msi -OutFile C:\\ProgramData\\svc\\osquery.msi;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/osquery.conf -OutFile C:\\ProgramData\\svc\\osquery.conf;
        Invoke-WebRequest -Uri http://${VPN_IP}:8443/osquery.flags -OutFile C:\\ProgramData\\svc\\osquery.flags;
        Stop-Service osqueryd -ErrorAction SilentlyContinue;
        Start-Process msiexec -ArgumentList '/i C:\\ProgramData\\svc\\osquery.msi /qn' -Wait;
        Stop-Service osqueryd -ErrorAction SilentlyContinue;
        Copy-Item C:\\ProgramData\\svc\\osquery.conf 'C:\\Program Files\\osquery\\osquery.conf' -Force;
        Copy-Item C:\\ProgramData\\svc\\osquery.flags 'C:\\Program Files\\osquery\\osquery.flags' -Force;
        Start-Service osqueryd;
        Get-Service osqueryd | Select-Object Status,Name
      \""

    echo "[*] Deploying Velociraptor to Windows via psexec..."
    impacket-psexec "${CREDS}@${TARGET_IP}" \
      "powershell -c \"
        Stop-Service Velociraptor -ErrorAction SilentlyContinue;
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

echo ""
echo "[+] Done. Check GUI at https://$VPN_IP:8889"
