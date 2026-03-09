#!/bin/bash
# common.sh — Shared functions library for all modules
# Sourced (not executed) by harden.sh and every module script.

# ---------------------------------------------------------------------------
# Color constants
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging functions
# ---------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# ---------------------------------------------------------------------------
# Interactive prompts
# ---------------------------------------------------------------------------

# prompt_input "message" "default"
# Reads a line from the user, showing the default in brackets.
# Returns the value (or the default if empty) via echo.
prompt_input() {
    local message="$1"
    local default="${2:-}"
    local value

    if [[ -n "$default" ]]; then
        read -rp "$message [$default]: " value
    else
        read -rp "$message: " value
    fi

    echo "${value:-$default}"
}

# prompt_password "message"
# Reads a password with hidden input. Returns the value via echo.
prompt_password() {
    local message="$1"
    local value

    read -rsp "$message: " value
    echo >&2  # newline after hidden input (sent to stderr so it doesn't mix with the return value)
    echo "$value"
}

# prompt_confirm "message"
# Asks a yes/no question. Returns 0 for yes, 1 for no.
prompt_confirm() {
    local message="$1"
    local answer

    read -rp "$message [y/N]: " answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# System checks
# ---------------------------------------------------------------------------

# check_root — exits with error if not running as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# check_alma — exits with error if the OS is not AlmaLinux
check_alma() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "/etc/os-release not found. Cannot determine OS."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" != "almalinux" ]]; then
        log_error "This script is designed for AlmaLinux. Detected: ${ID:-unknown}"
        exit 1
    fi
}

# check_internet — exits with error if there is no internet connectivity
check_internet() {
    if ! ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
        log_error "No internet connectivity. Please check your network."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

# section_header "title" — prints a visible section divider
section_header() {
    local title="$1"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}
