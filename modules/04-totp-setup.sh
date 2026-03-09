#!/bin/bash
# 04-totp-setup.sh — Set up TOTP-based two-factor auth with Google Authenticator
# Sourced by harden.sh — do not add set -euo pipefail here.

# --------------------------------------------------------------------------
# Step 1: Install required packages
# --------------------------------------------------------------------------
log_info "Installing EPEL release repository..."
dnf install -y epel-release

log_info "Installing Google Authenticator and QR code support..."
dnf install -y google-authenticator qrencode
log_success "Google Authenticator and qrencode installed."

# --------------------------------------------------------------------------
# Step 2: Configure PAM for SSH (idempotent)
# --------------------------------------------------------------------------
log_info "Configuring PAM for SSH TOTP authentication..."

# Back up current pam sshd config
cp /etc/pam.d/sshd "/etc/pam.d/sshd.bak.$(date +%s)"
log_info "Backed up /etc/pam.d/sshd."

# Add pam_google_authenticator.so at the TOP of /etc/pam.d/sshd (idempotent)
if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd; then
    log_warn "PAM Google Authenticator line already present — skipping."
else
    sed -i '1 a auth required pam_google_authenticator.so nullok' /etc/pam.d/sshd
    log_success "Added pam_google_authenticator.so to /etc/pam.d/sshd (nullok enabled)."
fi

# --------------------------------------------------------------------------
# Step 3: Run google-authenticator for the new user
# --------------------------------------------------------------------------
log_info "Generating TOTP credentials for '$NEW_USER'..."
su - "$NEW_USER" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3"

# --------------------------------------------------------------------------
# Step 4: Pause and wait for user to scan QR code
# --------------------------------------------------------------------------
log_warn "IMPORTANT: Scan the QR code above with your authenticator app (Google Authenticator, Authy, etc.)"
log_warn "Save the emergency scratch codes shown above somewhere safe!"

if ! prompt_confirm "Have you scanned the QR code and saved the scratch codes?"; then
    log_error "Aborted — please re-run after you are ready to scan the QR code."
    exit 1
fi

# --------------------------------------------------------------------------
# Step 5: Log scratch codes location
# --------------------------------------------------------------------------
log_info "Scratch codes stored in: /home/$NEW_USER/.google_authenticator"

log_success "TOTP two-factor authentication configured for '$NEW_USER'."
