#!/bin/bash
# 03-firewall.sh — Lock down firewall to allow only the custom SSH port
# Sourced by harden.sh — do not add set -euo pipefail here.

# --------------------------------------------------------------------------
# Step 1: Install firewalld
# --------------------------------------------------------------------------
log_info "Installing firewalld..."
dnf install -y firewalld
log_success "firewalld installed."

# --------------------------------------------------------------------------
# Step 2: Enable and start firewalld
# --------------------------------------------------------------------------
log_info "Enabling and starting firewalld..."
systemctl enable --now firewalld
log_success "firewalld is enabled and running."

# --------------------------------------------------------------------------
# Step 3: Remove default services
# --------------------------------------------------------------------------
log_info "Removing default firewall services..."

firewall-cmd --permanent --remove-service=ssh 2>/dev/null || true
log_info "Removed default SSH service."

firewall-cmd --permanent --remove-service=cockpit 2>/dev/null || true
log_info "Removed cockpit service."

firewall-cmd --permanent --remove-service=dhcpv6-client 2>/dev/null || true
log_info "Removed dhcpv6-client service."

log_success "Default services removed."

# --------------------------------------------------------------------------
# Step 4: Add custom SSH port
# --------------------------------------------------------------------------
log_info "Adding custom SSH port $SSH_PORT/tcp..."
firewall-cmd --permanent --add-port="$SSH_PORT"/tcp
log_success "Port $SSH_PORT/tcp added to firewall."

# --------------------------------------------------------------------------
# Step 5: Reload firewall
# --------------------------------------------------------------------------
log_info "Reloading firewall rules..."
firewall-cmd --reload
log_success "Firewall reloaded."

# --------------------------------------------------------------------------
# Step 6: Verify final state
# --------------------------------------------------------------------------
log_info "Final firewall state:"
firewall-cmd --list-all

log_success "Firewall lockdown complete — only port $SSH_PORT/tcp is open."
