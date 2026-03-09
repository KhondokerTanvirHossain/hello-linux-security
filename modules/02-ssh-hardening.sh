#!/bin/bash
# 02-ssh-hardening.sh — Harden SSH configuration
# Sourced by harden.sh. Variables available: $SSH_PORT, $NEW_USER

# =========================================================================
# Step 1: Back up current sshd_config
# =========================================================================
log_info "Backing up /etc/ssh/sshd_config ..."
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"
log_success "sshd_config backup created"

# =========================================================================
# Step 2: Write hardened SSH drop-in configuration
# =========================================================================
log_info "Writing hardened SSH config to /etc/ssh/sshd_config.d/99-hardening.conf ..."

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-hardening.conf <<EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthenticationMethods publickey,keyboard-interactive:pam
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $NEW_USER
X11Forwarding no
PermitEmptyPasswords no
LoginGraceTime 30
AllowAgentForwarding no
AllowTcpForwarding no
EOF

log_success "Hardened SSH configuration written"

# =========================================================================
# Step 3: Tell SELinux about the custom SSH port
# =========================================================================
log_info "Configuring SELinux for SSH on port $SSH_PORT ..."

# Ensure semanage is available
if ! command -v semanage &>/dev/null; then
    log_info "semanage not found — installing policycoreutils-python-utils ..."
    dnf install -y policycoreutils-python-utils
    log_success "policycoreutils-python-utils installed"
fi

# Try to add the port; if it already exists, modify it instead
if semanage port -a -t ssh_port_t -p tcp "$SSH_PORT" 2>/dev/null; then
    log_success "SELinux: added SSH port $SSH_PORT"
elif semanage port -m -t ssh_port_t -p tcp "$SSH_PORT" 2>/dev/null; then
    log_success "SELinux: modified existing entry for SSH port $SSH_PORT"
else
    log_error "Failed to configure SELinux for SSH port $SSH_PORT"
    exit 1
fi

# =========================================================================
# NOTE: sshd is NOT restarted here.
# harden.sh handles the restart after the firewall is configured,
# preventing lockouts from a port mismatch.
# =========================================================================
log_info "SSH hardening configured (sshd restart deferred until firewall is ready)"
