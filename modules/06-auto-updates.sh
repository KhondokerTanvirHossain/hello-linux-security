#!/bin/bash
# 06-auto-updates.sh — Enable automatic security updates via dnf-automatic
# Sourced by harden.sh — do not add set -euo pipefail here.

# --------------------------------------------------------------------------
# Step 1: Install dnf-automatic
# --------------------------------------------------------------------------
log_info "Installing dnf-automatic..."
dnf install -y dnf-automatic
log_success "dnf-automatic installed."

# --------------------------------------------------------------------------
# Step 2: Configure automatic updates
# --------------------------------------------------------------------------
log_info "Configuring /etc/dnf/automatic.conf to apply updates automatically..."
sed -i 's/^apply_updates.*/apply_updates = yes/' /etc/dnf/automatic.conf
log_success "apply_updates set to yes."

# --------------------------------------------------------------------------
# Step 3: Enable the dnf-automatic-install timer
# --------------------------------------------------------------------------
log_info "Enabling dnf-automatic-install.timer..."
systemctl enable --now dnf-automatic-install.timer
log_success "dnf-automatic-install.timer is enabled and running."

# --------------------------------------------------------------------------
# Step 4: Verify the timer is active
# --------------------------------------------------------------------------
log_info "Verifying dnf-automatic-install.timer status..."
if systemctl is-active dnf-automatic-install.timer &>/dev/null; then
    log_success "dnf-automatic-install.timer is active — automatic updates are enabled."
else
    log_error "dnf-automatic-install.timer is not active. Check 'systemctl status dnf-automatic-install.timer' for details."
fi
