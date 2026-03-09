#!/bin/bash
# harden.sh — Single entry point for AlmaLinux security hardening
# Run as root on a fresh AlmaLinux VM.

# ==========================================================================
# Phase 0: Pre-flight checks
# ==========================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/modules/common.sh"

section_header "Pre-flight Checks"

check_root
log_success "Running as root"

check_alma
log_success "AlmaLinux detected"

check_internet
log_success "Internet connectivity verified"

# Check for existing SSH key
if [[ ! -f /root/.ssh/authorized_keys ]] || [[ ! -s /root/.ssh/authorized_keys ]]; then
    log_warn "No SSH public key found in /root/.ssh/authorized_keys."
    log_warn "You may lose SSH access if key-based auth is enforced."
    if ! prompt_confirm "Continue without an existing SSH key?"; then
        log_error "Aborted by user. Add your SSH key first, then re-run."
        exit 1
    fi
else
    log_success "SSH public key found in /root/.ssh/authorized_keys"
fi

# ==========================================================================
# Phase 1: Interactive Prompts
# ==========================================================================
section_header "Configuration"

# --- Username ---
NEW_USER=$(prompt_input "Enter username" "admin")

if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log_error "Invalid username. Must start with a lowercase letter/underscore, contain only [a-z0-9_-], max 32 chars."
    exit 1
fi

# --- Password with confirmation ---
while true; do
    NEW_USER_PASS=$(prompt_password "Enter password for $NEW_USER")
    NEW_USER_PASS_CONFIRM=$(prompt_password "Confirm password for $NEW_USER")

    if [[ -z "$NEW_USER_PASS" ]]; then
        log_error "Password cannot be empty. Please try again."
        continue
    fi

    if [[ "$NEW_USER_PASS" == "$NEW_USER_PASS_CONFIRM" ]]; then
        break
    fi

    log_error "Passwords do not match. Please try again."
done
unset NEW_USER_PASS_CONFIRM

# --- SSH port ---
while true; do
    SSH_PORT=$(prompt_input "Enter SSH port" "2222")

    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1024 && SSH_PORT <= 65535 )); then
        break
    fi

    log_error "Invalid port. Must be a number between 1024 and 65535."
done

# --- Backup SSH key (optional) ---
BACKUP_KEY=$(prompt_input "Paste backup SSH public key (or press Enter to skip)" "")

# --- Summary ---
section_header "Configuration Summary"
log_info "Username:        $NEW_USER"
log_info "SSH Port:        $SSH_PORT"
if [[ -n "$BACKUP_KEY" ]]; then
    log_info "Backup SSH Key:  (provided)"
else
    log_info "Backup SSH Key:  (none)"
fi
log_info "Authentication:  SSH key (primary), password + TOTP (fallback)"

echo ""
if ! prompt_confirm "Proceed with these settings?"; then
    log_error "Aborted by user."
    exit 1
fi

# Export variables for use by modules
export NEW_USER NEW_USER_PASS SSH_PORT BACKUP_KEY

# Note: NEW_USER_PASS is unset in 01-user-setup.sh after chpasswd

# ==========================================================================
# Phase 2: Execute Modules
# ==========================================================================
section_header "Executing Hardening Modules"

for module in "$SCRIPT_DIR"/modules/[0-9]*.sh; do
    if [[ -f "$module" ]]; then
        section_header "Running $(basename "$module")"
        source "$module"
    fi
done

# ==========================================================================
# Phase 3: Install Helpers
# ==========================================================================
section_header "Installing helper commands"

if [[ -d "$SCRIPT_DIR/helpers" ]]; then
    for helper in "$SCRIPT_DIR"/helpers/*; do
        if [[ -f "$helper" ]]; then
            helper_name="$(basename "$helper")"
            cp "$helper" "/usr/local/bin/$helper_name"
            chmod +x "/usr/local/bin/$helper_name"
            # Replace SSH port placeholder with the actual port
            sed -i "s/{{SSH_PORT}}/$SSH_PORT/g" "/usr/local/bin/$helper_name"
            log_success "Installed $helper_name"
        fi
    done
else
    log_warn "No helpers directory found — skipping helper installation."
fi

# ==========================================================================
# Phase 4: Restart SSH (the critical moment)
# ==========================================================================
section_header "Activating SSH configuration"

systemctl restart sshd
log_success "SSH restarted on port $SSH_PORT"

# ==========================================================================
# Phase 5: Generate Report
# ==========================================================================
section_header "Generating security report"

REPORT_FILE="/home/$NEW_USER/security-report.txt"
OPEN_PORTS=$(firewall-cmd --list-ports 2>/dev/null || echo "(unable to query)")

cat > "$REPORT_FILE" <<REPORT
================================================================================
  AlmaLinux Security Hardening Report
================================================================================

Date:           $(date '+%Y-%m-%d %H:%M:%S %Z')
Username:       $NEW_USER
SSH Port:       $SSH_PORT

--------------------------------------------------------------------------------
  Authentication Methods
--------------------------------------------------------------------------------
  Primary:      SSH key-based authentication
  Fallback:     Password + TOTP (Google Authenticator)

--------------------------------------------------------------------------------
  Open Ports (firewalld)
--------------------------------------------------------------------------------
  $OPEN_PORTS

--------------------------------------------------------------------------------
  Security Layers Applied
--------------------------------------------------------------------------------
  [x] SSH hardening        — root login disabled, custom port, key auth
  [x] Firewall             — firewalld with minimal open ports
  [x] Fail2Ban             — brute-force protection on SSH
  [x] SELinux              — enforcing mode
  [x] AIDE                 — file integrity monitoring
  [x] Automatic updates    — dnf-automatic configured
  [x] Kernel hardening     — sysctl security parameters

--------------------------------------------------------------------------------
  Important File Locations
--------------------------------------------------------------------------------
  TOTP scratch codes:      /home/$NEW_USER/.google_authenticator
  This report:             $REPORT_FILE

--------------------------------------------------------------------------------
  Helper Commands Cheat Sheet
--------------------------------------------------------------------------------
  open-port <port>         Open a port in the firewall
  close-port <port>        Close a port in the firewall
  list-ports               List all open firewall ports
  security-status          Show overall security status

--------------------------------------------------------------------------------
  How to Test Your Connection
--------------------------------------------------------------------------------
  From your local machine, open a NEW terminal and run:

    ssh -i ~/.ssh/id_ed25519 -p $SSH_PORT $NEW_USER@<server-ip>

  DO NOT close this session until you have verified access!

================================================================================
REPORT

chown "$NEW_USER:$NEW_USER" "$REPORT_FILE"
log_success "Security report saved to $REPORT_FILE"

# ==========================================================================
# Phase 6: Verification
# ==========================================================================
section_header "Verification"

# Verify user exists
if id "$NEW_USER" &>/dev/null; then
    log_success "User '$NEW_USER' exists"
else
    log_error "User '$NEW_USER' was NOT created!"
fi

# Verify firewall
FW_PORTS=$(firewall-cmd --list-ports 2>/dev/null || echo "")
if [[ -n "$FW_PORTS" ]]; then
    log_success "Firewall ports open: $FW_PORTS"
else
    log_warn "No open firewall ports detected"
fi

# Verify fail2ban
if systemctl is-active fail2ban &>/dev/null; then
    log_success "Fail2Ban is active"
else
    log_warn "Fail2Ban is NOT active"
fi

# Verify SELinux
SELINUX_STATUS=$(getenforce 2>/dev/null || echo "unknown")
if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
    log_success "SELinux is enforcing"
else
    log_warn "SELinux status: $SELINUX_STATUS"
fi

# --- Final summary ---
section_header "Hardening Complete"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All security modules applied!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
log_info "Username:  $NEW_USER"
log_info "SSH Port:  $SSH_PORT"
log_info "Report:    $REPORT_FILE"
echo ""
log_info "Connect with:"
echo -e "  ${YELLOW}ssh -i ~/.ssh/id_ed25519 -p $SSH_PORT $NEW_USER@<server-ip>${NC}"
echo ""
echo -e "${RED}========================================${NC}"
echo -e "${RED}  WARNING: TEST IN A NEW TERMINAL${NC}"
echo -e "${RED}  before closing this session!${NC}"
echo -e "${RED}========================================${NC}"
