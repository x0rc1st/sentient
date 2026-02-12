#!/bin/bash
# sentient.sh — Main wrapper for the Sentient monitoring framework
# Orchestrates: setup → bootstrap → provision target(s)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PERSIST_DIR="/opt/htb-monitoring"

# ─── Banner ───────────────────────────────────────────────────────────────────

echo "╔═══════════════════════════════════════════════════╗"
echo "║              SENTIENT — HTB Monitoring            ║"
echo "║         Velociraptor Deployment Framework         ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# ─── Step 1: Setup (one-time) ────────────────────────────────────────────────

echo "[?] Is this a fresh Pwnbox / first-time setup?"
echo "    This downloads Velociraptor binaries, Sysmon, and rulesets."
read -rp "    Run setup? (y/N): " RUN_SETUP

if [[ "$RUN_SETUP" =~ ^[Yy]$ ]]; then
    echo ""
    echo "════════════════════════════════════════════════════"
    echo " STEP 1/3 — Running setup.sh"
    echo "════════════════════════════════════════════════════"
    bash "$SCRIPT_DIR/setup.sh"
    echo ""
    echo "[+] Setup complete."
else
    echo "[*] Skipping setup."
    if [ ! -x "$PERSIST_DIR/velociraptor" ]; then
        echo "[!] Warning: $PERSIST_DIR/velociraptor not found. You may need to run setup first."
        read -rp "    Continue anyway? (y/N): " FORCE_CONTINUE
        if [[ ! "$FORCE_CONTINUE" =~ ^[Yy]$ ]]; then
            echo "[-] Aborting."
            exit 1
        fi
    fi
fi

echo ""

# ─── Step 2: Bootstrap ──────────────────────────────────────────────────────

echo "[?] Start the Velociraptor server and asset server?"
echo "    This generates configs, lets you pick monitoring artifacts,"
echo "    and starts the server using your current VPN IP."
read -rp "    Run bootstrap? (Y/n): " RUN_BOOTSTRAP

if [[ ! "$RUN_BOOTSTRAP" =~ ^[Nn]$ ]]; then
    echo ""
    echo "════════════════════════════════════════════════════"
    echo " STEP 2/3 — Running bootstrap.sh"
    echo "════════════════════════════════════════════════════"
    bash "$SCRIPT_DIR/bootstrap.sh"
    echo ""
    echo "[+] Bootstrap complete."
else
    echo "[*] Skipping bootstrap."
fi

echo ""

# ─── Step 3: Provision Target(s) ────────────────────────────────────────────

echo "════════════════════════════════════════════════════"
echo " STEP 3/3 — Provision Lab Targets"
echo "════════════════════════════════════════════════════"
echo ""

PROVISION_MORE="y"
while [[ "$PROVISION_MORE" =~ ^[Yy]$ ]]; do

    read -rp "[?] Target IP: " TARGET_IP
    if [ -z "$TARGET_IP" ]; then
        echo "[-] No target IP provided. Skipping provisioning."
        break
    fi

    echo "[?] Target OS type:"
    echo "    1) Windows (default)"
    echo "    2) Linux"
    read -rp "    Select [1/2]: " OS_CHOICE
    case "$OS_CHOICE" in
        2) OS_TYPE="linux" ;;
        *) OS_TYPE="windows" ;;
    esac

    if [ "$OS_TYPE" = "windows" ]; then
        DEFAULT_CREDS="Administrator:password"
    else
        DEFAULT_CREDS="root:password"
    fi
    read -rp "[?] Credentials (user:pass) [$DEFAULT_CREDS]: " CREDS
    CREDS="${CREDS:-$DEFAULT_CREDS}"

    echo ""
    echo "────────────────────────────────────────────────────"
    echo " Provisioning $TARGET_IP ($OS_TYPE)"
    echo "────────────────────────────────────────────────────"
    bash "$SCRIPT_DIR/provision-target.sh" "$TARGET_IP" "$OS_TYPE" "$CREDS"

    echo ""
    read -rp "[?] Provision another target? (y/N): " PROVISION_MORE
    echo ""
done

# ─── Summary ─────────────────────────────────────────────────────────────────

VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "<unknown>")

echo "╔═══════════════════════════════════════════════════╗"
echo "║                 Session Summary                   ║"
echo "╠═══════════════════════════════════════════════════╣"
echo "║  Velociraptor GUI: https://$VPN_IP:8889"
echo "║  Credentials:      admin / admin"
echo "║  Asset Server:     http://$VPN_IP:8443"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "[*] All done. Happy hunting!"
