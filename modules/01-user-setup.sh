#!/bin/bash
# 01-user-setup.sh — Create a non-root user with sudo access and SSH keys
# Sourced by harden.sh — do not add set -euo pipefail here.

# --------------------------------------------------------------------------
# Step 1: Create the user (idempotent)
# --------------------------------------------------------------------------
if id "$NEW_USER" &>/dev/null; then
    log_warn "User '$NEW_USER' already exists — skipping creation."
else
    log_info "Creating user '$NEW_USER'..."
    useradd -m -s /bin/bash "$NEW_USER"
    log_success "User '$NEW_USER' created."
fi

# --------------------------------------------------------------------------
# Step 2: Set the user's password
# --------------------------------------------------------------------------
log_info "Setting password for '$NEW_USER'..."
echo "$NEW_USER:$NEW_USER_PASS" | chpasswd
log_success "Password set for '$NEW_USER'."

# --------------------------------------------------------------------------
# Step 3: Add user to the wheel group (sudo access)
# --------------------------------------------------------------------------
log_info "Adding '$NEW_USER' to wheel group..."
usermod -aG wheel "$NEW_USER"
log_success "'$NEW_USER' added to wheel group."

# --------------------------------------------------------------------------
# Step 4: Copy root's SSH authorized_keys to the new user
# --------------------------------------------------------------------------
log_info "Configuring SSH keys for '$NEW_USER'..."
mkdir -p /home/"$NEW_USER"/.ssh

if [[ -f /root/.ssh/authorized_keys ]]; then
    cp /root/.ssh/authorized_keys /home/"$NEW_USER"/.ssh/authorized_keys
    log_success "Root SSH keys copied to '$NEW_USER'."
else
    log_warn "No /root/.ssh/authorized_keys found — creating empty authorized_keys."
    touch /home/"$NEW_USER"/.ssh/authorized_keys
fi

# --------------------------------------------------------------------------
# Step 5: Append backup SSH key if provided
# --------------------------------------------------------------------------
if [[ -n "${BACKUP_KEY:-}" ]]; then
    log_info "Appending backup SSH key..."
    echo "$BACKUP_KEY" >> /home/"$NEW_USER"/.ssh/authorized_keys
    log_success "Backup SSH key added."
else
    log_info "No backup SSH key provided — skipping."
fi

# --------------------------------------------------------------------------
# Step 6: Set correct ownership and permissions on .ssh
# --------------------------------------------------------------------------
log_info "Setting SSH directory permissions..."
chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
chmod 700 /home/"$NEW_USER"/.ssh
chmod 600 /home/"$NEW_USER"/.ssh/authorized_keys
log_success "SSH permissions set (700 on .ssh, 600 on authorized_keys)."

# --------------------------------------------------------------------------
# Step 7: Configure sudo timeout
# --------------------------------------------------------------------------
log_info "Configuring sudo timeout for '$NEW_USER'..."
echo "Defaults timestamp_timeout=5" > /etc/sudoers.d/"$NEW_USER"

if visudo -cf /etc/sudoers.d/"$NEW_USER" &>/dev/null; then
    log_success "Sudo timeout configured (5 minutes) and validated."
else
    log_error "Sudoers file validation failed — removing invalid file."
    rm -f /etc/sudoers.d/"$NEW_USER"
fi

log_success "User setup complete for '$NEW_USER'."
