#!/bin/bash
# animations.sh — Shared animation library for Sentient framework
# Source this file from other scripts: source "$(dirname "$0")/animations.sh"

# ─── Color Palette (Cyberpunk/Hacker Theme) ──────────────────────────────────

C_GREEN="\033[38;5;46m"      # Neon green — primary
C_CYAN="\033[38;5;51m"       # Electric cyan — accent
C_BLUE="\033[38;5;33m"       # Steel blue — headers
C_RED="\033[38;5;196m"       # Alert red
C_AMBER="\033[38;5;214m"     # Alert amber
C_YELLOW="\033[38;5;226m"    # Alert yellow
C_GRAY="\033[38;5;240m"      # Dim gray — borders
C_LGRAY="\033[38;5;250m"     # Light gray — subtle text
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RESET="\033[0m"

# ─── Terminal Safety ─────────────────────────────────────────────────────────

SENTIENT_ANIMATE=true
if [[ ! -t 1 ]] || [[ "${-}" == *x* ]]; then
    SENTIENT_ANIMATE=false
fi

_sentient_cleanup() {
    # Restore cursor and colors on exit/interrupt
    if $SENTIENT_ANIMATE; then
        printf "\033[?25h"  # show cursor
        printf "$C_RESET"
    fi
}
trap _sentient_cleanup EXIT INT TERM

# ─── Status Messages ─────────────────────────────────────────────────────────

success() {
    printf "${C_GREEN}${C_BOLD}  [+]${C_RESET} ${C_GREEN}%s${C_RESET}\n" "$1"
}

info() {
    printf "${C_CYAN}  [*]${C_RESET} %s\n" "$1"
}

warn() {
    printf "${C_AMBER}  [!]${C_RESET} ${C_AMBER}%s${C_RESET}\n" "$1"
}

error() {
    printf "${C_RED}${C_BOLD}  [-]${C_RESET} ${C_RED}%s${C_RESET}\n" "$1"
}

ask() {
    printf "${C_YELLOW}  [?]${C_RESET} %s\n" "$1"
}

# ─── ASCII Banner ────────────────────────────────────────────────────────────

show_banner() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    echo ""
    if [ "$cols" -lt 72 ]; then
        # Compact fallback for narrow terminals
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
}

# ─── Step / Phase Headers ────────────────────────────────────────────────────

show_step_header() {
    local step="$1" total="$2" text="$3"
    echo ""
    if $SENTIENT_ANIMATE; then
        printf "${C_GRAY}  "
        local line="════════════════════════════════════════════════════"
        for (( i=0; i<${#line}; i++ )); do
            printf "${line:$i:1}"
            sleep 0.005
        done
        printf "${C_RESET}\n"
    else
        printf "${C_GRAY}  ════════════════════════════════════════════════════${C_RESET}\n"
    fi
    printf "${C_BLUE}${C_BOLD}   STEP %s/%s${C_RESET} ${C_GRAY}─${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$step" "$total" "$text"
    printf "${C_GRAY}  ════════════════════════════════════════════════════${C_RESET}\n"
    echo ""
}

show_phase_header() {
    local text="$1"
    echo ""
    printf "${C_GRAY}  ┌────────────────────────────────────────────────────┐${C_RESET}\n"
    printf "${C_GRAY}  │${C_RESET} ${C_CYAN}${C_BOLD}%-50s${C_RESET} ${C_GRAY}│${C_RESET}\n" "$text"
    printf "${C_GRAY}  └────────────────────────────────────────────────────┘${C_RESET}\n"
    echo ""
}

# ─── Spinners ─────────────────────────────────────────────────────────────────

run_with_spinner() {
    local msg="$1"
    shift
    local tmpfile
    tmpfile=$(mktemp)

    if ! $SENTIENT_ANIMATE; then
        printf "  [*] %s\n" "$msg"
        if "$@" > "$tmpfile" 2>&1; then
            rm -f "$tmpfile"
            return 0
        else
            local ec=$?
            cat "$tmpfile"
            rm -f "$tmpfile"
            return $ec
        fi
    fi

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

    # Run command in background (stdin from /dev/null so psexec doesn't choke)
    "$@" < /dev/null > "$tmpfile" 2>&1 &
    local pid=$!

    # Hide cursor
    printf "\033[?25l"

    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}  %s${C_RESET} %s" "${frames[$i]}" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done

    # Get exit code (|| prevents set -e from killing the script)
    local exit_code=0
    wait "$pid" || exit_code=$?

    # Clear line and show cursor
    printf "\r\033[K"
    printf "\033[?25h"

    if [ $exit_code -eq 0 ]; then
        printf "${C_GREEN}  ✓${C_RESET} %s\n" "$msg"
        rm -f "$tmpfile"
    else
        printf "${C_RED}  ✗${C_RESET} %s\n" "$msg"
        printf "${C_DIM}"
        cat "$tmpfile"
        printf "${C_RESET}"
        rm -f "$tmpfile"
    fi

    return $exit_code
}

run_with_spinner_output() {
    local msg="$1" outfile="$2"
    shift 2
    local tmpfile
    tmpfile=$(mktemp)

    if ! $SENTIENT_ANIMATE; then
        printf "  [*] %s\n" "$msg"
        if "$@" > "$outfile" 2>"$tmpfile"; then
            rm -f "$tmpfile"
            return 0
        else
            local ec=$?
            cat "$tmpfile"
            rm -f "$tmpfile"
            return $ec
        fi
    fi

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

    # Run command with stdout to outfile, stderr to tmpfile
    "$@" < /dev/null > "$outfile" 2>"$tmpfile" &
    local pid=$!

    printf "\033[?25l"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}  %s${C_RESET} %s" "${frames[$i]}" "$msg"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.08
    done

    local exit_code=0
    wait "$pid" || exit_code=$?

    printf "\r\033[K"
    printf "\033[?25h"

    if [ $exit_code -eq 0 ]; then
        printf "${C_GREEN}  ✓${C_RESET} %s\n" "$msg"
        rm -f "$tmpfile"
    else
        printf "${C_RED}  ✗${C_RESET} %s\n" "$msg"
        printf "${C_DIM}"
        cat "$tmpfile"
        printf "${C_RESET}"
        rm -f "$tmpfile"
    fi

    return $exit_code
}

# ─── Deployment Step (psexec / SSH) ──────────────────────────────────────────

run_deployment_step() {
    local label="$1" step="$2" total="$3"
    shift 3
    local tmpfile
    tmpfile=$(mktemp)

    if ! $SENTIENT_ANIMATE; then
        printf "  [%s/%s] Deploying %s...\n" "$step" "$total" "$label"
        "$@" < /dev/null > "$tmpfile" 2>&1
        local ec=$?
        # impacket-psexec crashes with do_EOF in a non-fatal background thread
        # when stdin is closed. The actual command still executes via SMB.
        # Strip the thread traceback and normalize exit code if SMB connected.
        if [ $ec -ne 0 ] && grep -q 'Exception in thread' "$tmpfile" 2>/dev/null; then
            sed '/Exception in thread/,$d' "$tmpfile" > "${tmpfile}.clean" && mv "${tmpfile}.clean" "$tmpfile"
            grep -q 'Opening SVCManager' "$tmpfile" 2>/dev/null && ec=0
        fi
        if [ $ec -eq 0 ]; then
            tail -3 "$tmpfile"
            rm -f "$tmpfile"
            return 0
        else
            cat "$tmpfile"
            rm -f "$tmpfile"
            return $ec
        fi
    fi

    local arrows=(">" ">>" ">>>" ">>>>" ">>>" ">>" ">")

    # Run command in background (stdin from /dev/null to detach from terminal)
    "$@" < /dev/null > "$tmpfile" 2>&1 &
    local pid=$!

    printf "\033[?25l"
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${C_CYAN}  %-4s${C_RESET} ${C_BOLD}[%s/%s]${C_RESET} Deploying ${C_GREEN}%s${C_RESET}..." "${arrows[$i]}" "$step" "$total" "$label"
        i=$(( (i + 1) % ${#arrows[@]} ))
        sleep 0.2
    done

    local exit_code=0
    wait "$pid" || exit_code=$?

    # impacket-psexec crashes with do_EOF in a non-fatal background thread
    # when stdin is closed. The actual command still executes via SMB.
    # Strip the thread traceback and normalize exit code if SMB connected.
    if [ $exit_code -ne 0 ] && grep -q 'Exception in thread' "$tmpfile" 2>/dev/null; then
        sed '/Exception in thread/,$d' "$tmpfile" > "${tmpfile}.clean" && mv "${tmpfile}.clean" "$tmpfile"
        grep -q 'Opening SVCManager' "$tmpfile" 2>/dev/null && exit_code=0
    fi

    printf "\r\033[K"
    printf "\033[?25h"

    if [ $exit_code -eq 0 ]; then
        printf "${C_GREEN}  ✓${C_RESET} ${C_BOLD}[%s/%s]${C_RESET} %s deployed\n" "$step" "$total" "$label"
        # Show last 3 lines of output (service status) dimmed
        printf "${C_DIM}"
        tail -3 "$tmpfile"
        printf "${C_RESET}"
    else
        printf "${C_RED}  ✗${C_RESET} ${C_BOLD}[%s/%s]${C_RESET} %s ${C_RED}FAILED${C_RESET}\n" "$step" "$total" "$label"
        printf "${C_DIM}"
        cat "$tmpfile"
        printf "${C_RESET}"
    fi

    rm -f "$tmpfile"
    return $exit_code
}

# ─── Enrollment Wait ─────────────────────────────────────────────────────────

enrollment_wait() {
    local seconds="$1"

    if ! $SENTIENT_ANIMATE; then
        printf "  [*] Waiting %s seconds for enrollment...\n" "$seconds"
        sleep "$seconds"
        return
    fi

    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    printf "\033[?25l"

    local fi=0
    for (( remaining=seconds; remaining>0; remaining-- )); do
        for (( tick=0; tick<10; tick++ )); do
            printf "\r${C_CYAN}  %s${C_RESET} Waiting for enrollment... ${C_BOLD}%ss${C_RESET}" "${frames[$fi]}" "$remaining"
            fi=$(( (fi + 1) % ${#frames[@]} ))
            sleep 0.1
        done
    done

    printf "\r\033[K"
    printf "\033[?25h"
    printf "${C_GREEN}  ✓${C_RESET} Enrollment wait complete\n"
}

# ─── Summary Box ─────────────────────────────────────────────────────────────

show_summary_box() {
    local max_len=0
    for line in "$@"; do
        local stripped
        stripped=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        [ ${#stripped} -gt $max_len ] && max_len=${#stripped}
    done
    local width=$(( max_len + 4 ))
    [ $width -lt 52 ] && width=52

    local border=""
    for (( i=0; i<width; i++ )); do border+="═"; done

    echo ""
    printf "${C_GREEN}  ╔%s╗${C_RESET}\n" "$border"
    printf "${C_GREEN}  ║${C_RESET}${C_BOLD}%-*s${C_RESET}${C_GREEN}║${C_RESET}\n" "$width" "  Session Summary"
    printf "${C_GREEN}  ╠%s╣${C_RESET}\n" "$border"
    for line in "$@"; do
        local stripped
        stripped=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local pad=$(( width - ${#stripped} ))
        printf "${C_GREEN}  ║${C_RESET} %b%*s${C_GREEN}║${C_RESET}\n" "$line" "$((pad - 1))" ""
    done
    printf "${C_GREEN}  ╚%s╝${C_RESET}\n" "$border"
    echo ""
}

# ─── Typewriter Effect ───────────────────────────────────────────────────────

typewrite() {
    local text="$1"
    if ! $SENTIENT_ANIMATE; then
        printf "  %s\n" "$text"
        return
    fi
    printf "  "
    for (( i=0; i<${#text}; i++ )); do
        printf "%s" "${text:$i:1}"
        sleep 0.03
    done
    printf "\n"
}

# ─── Glitch Text ─────────────────────────────────────────────────────────────

glitch_text() {
    local text="$1"
    if ! $SENTIENT_ANIMATE; then
        printf "${C_RED}  %s${C_RESET}\n" "$text"
        return
    fi

    local glitch_chars="!@#$%^&*<>/\\|{}[]~"
    # Show corrupted version briefly
    printf "\033[?25l"
    for (( pass=0; pass<3; pass++ )); do
        printf "\r  ${C_RED}"
        for (( i=0; i<${#text}; i++ )); do
            local ch="${text:$i:1}"
            if [ "$ch" = " " ]; then
                printf " "
            elif (( RANDOM % 3 == 0 )); then
                printf "%s" "${glitch_chars:$((RANDOM % ${#glitch_chars})):1}"
            else
                printf "%s" "$ch"
            fi
        done
        printf "${C_RESET}"
        sleep 0.1
    done
    # Reveal real text
    printf "\r  ${C_RED}${C_BOLD}%s${C_RESET}\n" "$text"
    printf "\033[?25h"
}
