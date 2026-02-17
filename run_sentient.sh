#!/bin/bash
# run_sentient.sh — Clone and launch the Sentient monitoring framework

# ─── Inline Colors & Safety ──────────────────────────────────────────────────

C_GREEN="\033[38;5;46m"
C_CYAN="\033[38;5;51m"
C_GRAY="\033[38;5;240m"
C_DIM="\033[2m"
C_BOLD="\033[1m"
C_RESET="\033[0m"

_cleanup() { printf "\033[?25h${C_RESET}"; }
trap _cleanup EXIT INT TERM

ANIMATE=true
[[ ! -t 1 ]] && ANIMATE=false

# ─── Clear Screen & Banner ───────────────────────────────────────────────────

clear
cols=$(tput cols 2>/dev/null || echo 80)

echo ""
if [ "$cols" -lt 72 ]; then
    printf "${C_GREEN}${C_BOLD}  >>> S3NS3 — HTB Monitoring Framework <<<${C_RESET}\n"
else
    printf "${C_GREEN}${C_BOLD}"
    cat <<'BANNER'
   ███████╗██████╗ ███╗   ██╗███████╗██████╗
   ██╔════╝╚════██╗████╗  ██║██╔════╝╚════██╗
   ███████╗ █████╔╝██╔██╗ ██║███████╗ █████╔╝
   ╚════██║ ╚═══██╗██║╚██╗██║╚════██║ ╚═══██╗
   ███████║██████╔╝██║ ╚████║███████║██████╔╝
   ╚══════╝╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═════╝
BANNER
    printf "${C_RESET}"
    printf "${C_GRAY}   ──────────────────────────────────────────────────────────────────${C_RESET}\n"
    printf "${C_CYAN}           Velociraptor Deployment Framework${C_RESET}  ${C_GRAY}│${C_RESET}  ${C_DIM}HTB Monitoring${C_RESET}\n"
    printf "${C_GRAY}   ──────────────────────────────────────────────────────────────────${C_RESET}\n"
fi
echo ""

# ─── Clone with Spinner ──────────────────────────────────────────────────────

if $ANIMATE; then
    frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    tmpfile=$(mktemp)

    git clone https://github.com/x0rc1st/sentient.git > "$tmpfile" 2>&1 &
    pid=$!

    printf "\033[?25l"
    i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}  %s${C_RESET} Cloning S3NS3 repository..." "${frames[$i]}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done

    wait "$pid"
    ec=$?
    printf "\r\033[K\033[?25h"

    if [ $ec -eq 0 ]; then
        printf "${C_GREEN}  ✓${C_RESET} Repository cloned\n"
    else
        printf "\033[38;5;196m  ✗${C_RESET} Clone failed\n"
        cat "$tmpfile"
        rm -f "$tmpfile"
        exit 1
    fi
    rm -f "$tmpfile"
else
    git clone https://github.com/x0rc1st/sentient.git
fi

# ─── Launch ──────────────────────────────────────────────────────────────────

echo ""
printf "${C_GREEN}${C_BOLD}  ▶${C_RESET} Launching S3NS3...\n"
echo ""

cd sentient
sudo bash sentient.sh
