#!/bin/bash
# 08-monitoring.sh — Set up file integrity monitoring (AIDE) and logging
# Sourced by harden.sh — do not add set -euo pipefail here.

# ==========================================================================
#  AIDE — Advanced Intrusion Detection Environment
# ==========================================================================

# --------------------------------------------------------------------------
# Step 1: Install AIDE
# --------------------------------------------------------------------------
log_info "Installing AIDE (file integrity monitoring)..."
dnf install -y aide
log_success "AIDE installed."

# --------------------------------------------------------------------------
# Step 2: Initialize AIDE database
# --------------------------------------------------------------------------
log_info "Initializing AIDE database (this may take a minute or two)..."
aide --init
log_success "AIDE database initialized."

# --------------------------------------------------------------------------
# Step 3: Move the new database into place
# --------------------------------------------------------------------------
log_info "Activating AIDE database..."
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
log_success "AIDE database is active at /var/lib/aide/aide.db.gz."

# --------------------------------------------------------------------------
# Step 4: Add daily AIDE cron job
# --------------------------------------------------------------------------
log_info "Adding daily AIDE integrity check cron job..."
cat > /etc/cron.d/aide-check <<'EOF'
0 3 * * * root /usr/sbin/aide --check > /var/log/aide-check.log 2>&1
EOF
log_success "AIDE cron job created — runs daily at 03:00 (/etc/cron.d/aide-check)."

# ==========================================================================
#  Journal persistence
# ==========================================================================

# --------------------------------------------------------------------------
# Step 5: Enable persistent journal logging
# --------------------------------------------------------------------------
log_info "Enabling persistent journal logging..."
mkdir -p /var/log/journal
systemctl restart systemd-journald
log_success "systemd-journald configured for persistent logging."

# ==========================================================================
#  NTP — Clock accuracy (important for TOTP)
# ==========================================================================

# --------------------------------------------------------------------------
# Step 6: Enable and start chronyd
# --------------------------------------------------------------------------
log_info "Enabling and starting chronyd for NTP time synchronisation..."
systemctl enable --now chronyd
log_success "chronyd is enabled and running."

# --------------------------------------------------------------------------
# Step 7: Verify NTP tracking
# --------------------------------------------------------------------------
log_info "Checking chrony tracking status..."
if chronyc tracking 2>&1; then
    log_success "NTP time synchronisation is active."
else
    log_warn "chronyc tracking did not return immediately — this is normal on first start."
fi

log_success "Monitoring and logging setup complete."
