#!/bin/bash
# sentient.sh — Main wrapper for the Sentient monitoring framework
# Orchestrates: setup → bootstrap → provision target(s)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PERSIST_DIR="/opt/htb-monitoring"

source "$SCRIPT_DIR/animations.sh"

# ─── Banner ───────────────────────────────────────────────────────────────────

show_banner

# ─── Step 1: Setup (one-time) ────────────────────────────────────────────────

ask "Is this a fresh Pwnbox / first-time setup?"
info "This downloads Velociraptor binaries, Sysmon, osquery, and rulesets."
read -rp "    Run setup? (y/N): " RUN_SETUP

if [[ "$RUN_SETUP" =~ ^[Yy]$ ]]; then
    show_step_header 1 3 "Running setup.sh"
    bash "$SCRIPT_DIR/setup.sh"
    echo ""
    success "Setup complete."
else
    info "Skipping setup."
    if [ ! -x "$PERSIST_DIR/velociraptor" ]; then
        warn "Warning: $PERSIST_DIR/velociraptor not found. You may need to run setup first."
        read -rp "    Continue anyway? (y/N): " FORCE_CONTINUE
        if [[ ! "$FORCE_CONTINUE" =~ ^[Yy]$ ]]; then
            error "Aborting."
            exit 1
        fi
    fi
fi

echo ""

# ─── Step 2: Bootstrap ──────────────────────────────────────────────────────

ask "Start the Velociraptor server and asset server?"
info "This generates configs, lets you pick monitoring artifacts,"
info "and starts the server using your current VPN IP."
read -rp "    Run bootstrap? (Y/n): " RUN_BOOTSTRAP

if [[ ! "$RUN_BOOTSTRAP" =~ ^[Nn]$ ]]; then
    show_step_header 2 3 "Running bootstrap.sh"
    bash "$SCRIPT_DIR/bootstrap.sh"
    echo ""
    success "Bootstrap complete."
else
    info "Skipping bootstrap."
fi

echo ""

# ─── Step 3: Provision Target(s) ────────────────────────────────────────────

show_step_header 3 3 "Provision Lab Targets"

PROVISION_MORE="y"
while [[ "$PROVISION_MORE" =~ ^[Yy]$ ]]; do

    read -rp "$(printf "${C_YELLOW}  [?]${C_RESET} Target IP: ")" TARGET_IP
    if [ -z "$TARGET_IP" ]; then
        error "No target IP provided. Skipping provisioning."
        break
    fi

    ask "Target OS type:"
    printf "${C_CYAN}    1)${C_RESET} Windows (default)\n"
    printf "${C_CYAN}    2)${C_RESET} Linux\n"
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
    read -rp "$(printf "${C_YELLOW}  [?]${C_RESET} Credentials (user:pass) [$DEFAULT_CREDS]: ")" CREDS
    CREDS="${CREDS:-$DEFAULT_CREDS}"

    show_phase_header "Provisioning $TARGET_IP ($OS_TYPE)"
    bash "$SCRIPT_DIR/provision-target.sh" "$TARGET_IP" "$OS_TYPE" "$CREDS"

    echo ""
    read -rp "$(printf "${C_YELLOW}  [?]${C_RESET} Provision another target? (y/N): ")" PROVISION_MORE
    echo ""
done

# ─── Summary ─────────────────────────────────────────────────────────────────

VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "<unknown>")

show_summary_box \
    "$(printf "${C_CYAN}Velociraptor GUI:${C_RESET}  https://$VPN_IP:8889")" \
    "$(printf "${C_CYAN}Credentials:${C_RESET}       admin / admin")" \
    "$(printf "${C_CYAN}Asset Server:${C_RESET}      http://$VPN_IP:8443")" \
    "$(printf "${C_CYAN}Webhook:${C_RESET}           http://127.0.0.1:9000")"

typewrite "$(printf "${C_GREEN}All done. Happy hunting!${C_RESET}")"
