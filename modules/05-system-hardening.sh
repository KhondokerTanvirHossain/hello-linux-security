#!/bin/bash
# 05-system-hardening.sh — Kernel, SELinux, service hardening, and password policy
# Sourced by harden.sh. Variables available: $NEW_USER

# =========================================================================
# Step 1: Harden kernel parameters via sysctl
# =========================================================================
log_info "Writing hardened kernel parameters to /etc/sysctl.d/99-hardening.conf ..."

cat > /etc/sysctl.d/99-hardening.conf <<EOF
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_all = 1
fs.suid_dumpable = 0
EOF

log_success "Hardened sysctl config written"

log_info "Applying sysctl parameters ..."
sysctl -p /etc/sysctl.d/99-hardening.conf
log_success "Kernel parameters applied"

# =========================================================================
# Step 2: Enforce SELinux
# =========================================================================
log_info "Checking SELinux status ..."

if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        log_success "SELinux is already Enforcing"
    elif [[ "$SELINUX_STATUS" == "Permissive" ]]; then
        log_warn "SELinux is Permissive — setting to Enforcing ..."
        setenforce 1
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        log_success "SELinux set to Enforcing"
    elif [[ "$SELINUX_STATUS" == "Disabled" ]]; then
        log_warn "SELinux is Disabled — cannot enable at runtime."
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        log_warn "Set SELINUX=enforcing in /etc/selinux/config — will activate after reboot."
    fi
else
    log_warn "getenforce not found — SELinux may not be installed"
fi

# =========================================================================
# Step 3: Disable unused services
# =========================================================================
log_info "Disabling unused services ..."

systemctl disable --now postfix 2>/dev/null || true
systemctl disable --now rpcbind 2>/dev/null || true
systemctl disable --now cups 2>/dev/null || true

log_success "Unused services disabled (postfix, rpcbind, cups)"

# =========================================================================
# Step 4: Lock down cron and at
# =========================================================================
log_info "Restricting cron and at access to '$NEW_USER' ..."

printf '%s\n' root "$NEW_USER" > /etc/cron.allow
printf '%s\n' root "$NEW_USER" > /etc/at.allow

log_success "cron.allow and at.allow configured for '$NEW_USER'"

# =========================================================================
# Step 5: Disable USB storage (remote VM — not needed)
# =========================================================================
log_info "Disabling USB storage module ..."

echo "blacklist usb-storage" > /etc/modprobe.d/disable-usb.conf

log_success "USB storage blacklisted via /etc/modprobe.d/disable-usb.conf"

# =========================================================================
# Step 6: Disable core dumps
# =========================================================================
log_info "Checking core dump limits ..."

if grep -q '^\* hard core 0' /etc/security/limits.conf; then
    log_success "Core dumps already disabled in limits.conf"
else
    log_info "Adding core dump restriction to limits.conf ..."
    echo "* hard core 0" >> /etc/security/limits.conf
    log_success "Core dumps disabled (added '* hard core 0' to limits.conf)"
fi

# =========================================================================
# Step 7: Password quality policy
# =========================================================================
log_info "Installing libpwquality ..."
dnf install -y libpwquality
log_success "libpwquality installed"

log_info "Configuring password quality policy in /etc/security/pwquality.conf ..."

sed -i 's/^# \?minlen.*/minlen = 14/' /etc/security/pwquality.conf
sed -i 's/^# \?dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# \?ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# \?lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# \?ocredit.*/ocredit = -1/' /etc/security/pwquality.conf

log_success "Password policy configured (minlen=14, require digit/upper/lower/special)"

log_success "System hardening complete."
