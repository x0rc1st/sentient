#!/bin/bash
# /opt/htb-monitoring/provision_target.sh
# Usage: ./provision-target.sh <target_ip> [windows|linux] [creds]
# Example: ./provision-target.sh 10.129.2.174 windows 'htb-student:Academy_student_AD!'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/animations.sh"

TARGET_IP="$1"
OS_TYPE="${2:-windows}"
CREDS="${3:-Administrator:password}"

VPN_IP=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PERSIST_DIR="/opt/htb-monitoring"
WORK_DIR="/tmp/velo"
API_CONFIG="$WORK_DIR/api.config.yaml"

if [ -z "$TARGET_IP" ]; then
    echo "Usage: $0 <target_ip> [windows|linux] [user:pass]"
    exit 1
fi

info "Pwnbox IP: $VPN_IP"
info "Target: $TARGET_IP ($OS_TYPE)"

if [ "$OS_TYPE" = "windows" ]; then

    show_phase_header "Windows Deployment via WMIExec"

    run_deployment_step "Sysmon + osquery + Velociraptor" 1 1 \
        impacket-wmiexec "${CREDS}@${TARGET_IP}" \
        "powershell -c \"\$ProgressPreference = 'SilentlyContinue'; mkdir C:\\ProgramData\\svc -Force | Out-Null; Stop-Service Velociraptor -ErrorAction SilentlyContinue; \$wc1 = New-Object System.Net.WebClient; \$wc2 = New-Object System.Net.WebClient; \$wc3 = New-Object System.Net.WebClient; \$wc4 = New-Object System.Net.WebClient; \$wc5 = New-Object System.Net.WebClient; \$wc6 = New-Object System.Net.WebClient; \$wc7 = New-Object System.Net.WebClient; \$t1 = \$wc1.DownloadFileTaskAsync('http://${VPN_IP}:8443/Sysmon64.exe', 'C:\\ProgramData\\svc\\Sysmon64.exe'); \$t2 = \$wc2.DownloadFileTaskAsync('http://${VPN_IP}:8443/sysmonconfig-excludes-only.xml', 'C:\\ProgramData\\svc\\sysmonconfig.xml'); \$t3 = \$wc3.DownloadFileTaskAsync('http://${VPN_IP}:8443/osquery.zip', 'C:\\ProgramData\\svc\\osquery.zip'); \$t4 = \$wc4.DownloadFileTaskAsync('http://${VPN_IP}:8443/osquery.conf', 'C:\\ProgramData\\svc\\osquery.conf'); \$t5 = \$wc5.DownloadFileTaskAsync('http://${VPN_IP}:8443/osquery.flags', 'C:\\ProgramData\\svc\\osquery.flags'); \$t6 = \$wc6.DownloadFileTaskAsync('http://${VPN_IP}:8443/velociraptor.exe', 'C:\\ProgramData\\svc\\svc.exe'); \$t7 = \$wc7.DownloadFileTaskAsync('http://${VPN_IP}:8443/client.config.yaml', 'C:\\ProgramData\\svc\\c.yaml'); [System.Threading.Tasks.Task]::WaitAll(@(\$t1,\$t2,\$t3,\$t4,\$t5,\$t6,\$t7)); C:\\ProgramData\\svc\\svc.exe service install --config C:\\ProgramData\\svc\\c.yaml; Start-Sleep -Seconds 1; Start-Service Velociraptor; Start-Process -FilePath C:\\ProgramData\\svc\\Sysmon64.exe -ArgumentList '-u force' -Wait -ErrorAction SilentlyContinue; Start-Process -FilePath C:\\ProgramData\\svc\\Sysmon64.exe -ArgumentList '-accepteula -i C:\\ProgramData\\svc\\sysmonconfig.xml' -Wait; Remove-Item C:\\ProgramData\\svc\\osquery_tmp -Recurse -Force -ErrorAction SilentlyContinue; Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('C:\\ProgramData\\svc\\osquery.zip', 'C:\\ProgramData\\svc\\osquery_tmp'); \$dir = (Get-ChildItem C:\\ProgramData\\svc\\osquery_tmp -Directory | Select-Object -First 1).FullName; Copy-Item -Path (\$dir + '\\Program Files\\osquery') -Destination 'C:\\Program Files\\osquery' -Recurse -Force; Copy-Item C:\\ProgramData\\svc\\osquery.conf 'C:\\Program Files\\osquery\\osquery.conf' -Force; Copy-Item C:\\ProgramData\\svc\\osquery.flags 'C:\\Program Files\\osquery\\osquery.flags' -Force; New-Service -Name osqueryd -BinaryPathName 'C:\\Progra~1\\osquery\\osqueryd\\osqueryd.exe --flagfile=C:\\Progra~1\\osquery\\osquery.flags' -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service osqueryd; Get-Service Sysmon64,osqueryd,Velociraptor -ErrorAction SilentlyContinue | Select-Object Status,Name\""

else

    show_phase_header "Linux Deployment via SSH"

    run_deployment_step "Velociraptor" 1 1 \
        ssh -o StrictHostKeyChecking=no root@"$TARGET_IP" bash -c \
        "'pkill -f velociraptor || true; mkdir -p /opt/svc; curl -s http://${VPN_IP}:8443/velociraptor -o /opt/svc/svc; curl -s http://${VPN_IP}:8443/client.config.yaml -o /opt/svc/c.yaml; chmod +x /opt/svc/svc; /opt/svc/svc --config /opt/svc/c.yaml client -d; pgrep -a svc'"

fi

# Poll for enrollment (check every 2s, up to 5 attempts)
CLIENT_ID=""
for attempt in 1 2 3 4 5; do
    enrollment_wait 2
    CLIENT_ID=$($PERSIST_DIR/velociraptor \
      --api_config "$API_CONFIG" \
      query "SELECT client_id FROM clients() WHERE last_ip =~ '${TARGET_IP}' ORDER BY last_seen_at DESC LIMIT 1" \
      --format json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['client_id'] if d else '')" 2>/dev/null)
    if [ -n "$CLIENT_ID" ]; then
        break
    fi
done

if [ -z "$CLIENT_ID" ]; then
    glitch_text "Client not found. Check server logs."
    exit 1
fi

success "Client enrolled: $CLIENT_ID"

echo ""
success "Done. Check GUI at https://$VPN_IP:8889"
