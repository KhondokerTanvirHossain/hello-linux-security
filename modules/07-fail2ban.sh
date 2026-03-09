#!/bin/bash
# 07-fail2ban.sh — Install and configure fail2ban for brute-force protection
# Sourced by harden.sh — do not add set -euo pipefail here.

# --------------------------------------------------------------------------
# Step 1: Install fail2ban and dependencies
# --------------------------------------------------------------------------
log_info "Installing EPEL release repository (if not already present)..."
dnf install -y epel-release

log_info "Installing fail2ban..."
dnf install -y fail2ban
log_success "fail2ban installed."

# --------------------------------------------------------------------------
# Step 2: Write jail.local configuration
# --------------------------------------------------------------------------
log_info "Writing /etc/fail2ban/jail.local..."

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
maxretry = 3
bantime = 86400
EOF

log_success "fail2ban jail.local configured (SSH port: $SSH_PORT)."

# --------------------------------------------------------------------------
# Step 3: Enable and start fail2ban
# --------------------------------------------------------------------------
log_info "Enabling and starting fail2ban..."
systemctl enable --now fail2ban
log_success "fail2ban is enabled and running."

# --------------------------------------------------------------------------
# Step 4: Verify sshd jail is active
# --------------------------------------------------------------------------
log_info "Verifying fail2ban sshd jail status..."

# fail2ban needs a moment to create its socket after starting
for i in 1 2 3 4 5; do
    if fail2ban-client status sshd &>/dev/null; then
        fail2ban-client status sshd
        log_success "fail2ban brute-force protection is active for SSH on port $SSH_PORT."
        break
    fi
    if [[ $i -eq 5 ]]; then
        log_warn "fail2ban socket not ready after 5s — service started but verification skipped."
        break
    fi
    sleep 1
done
