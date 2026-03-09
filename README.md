# Hello Linux Security

A clone-and-run security hardening toolkit for AlmaLinux VMs. Designed for freshly provisioned servers with public IPs — balances strong security with day-to-day usability.

## What This Does

- **SSH hardening** — Non-standard port, root login disabled, key-based auth (primary) with password+TOTP fallback
- **Firewall lockdown** — All ports closed except SSH, with helper commands to manage ports
- **Brute force protection** — Fail2Ban bans IPs after 3 failed SSH attempts (24h ban)
- **System hardening** — SELinux enforcing, kernel security parameters, disabled unused services
- **Automatic updates** — dnf-automatic applies security patches automatically
- **File integrity monitoring** — AIDE checks for unauthorized file changes daily
- **Access control** — Sudo with 5-minute timeout, cron/at restricted, USB storage disabled

## Prerequisites

Before running the script:

1. SSH into your VM as root with your password
2. Copy your SSH public key to the server:
   ```bash
   ssh-copy-id root@your-server-ip
   ```
3. Verify key-based login works:
   ```bash
   ssh -i ~/.ssh/id_ed25519 root@your-server-ip
   ```

## Quick Start

```bash
# On your AlmaLinux VM as root:
git clone https://github.com/your-username/hello-linux-security.git
cd hello-linux-security
chmod +x harden.sh
./harden.sh
```

The script will prompt you for:
- **Username** (default: `admin`)
- **Password** for the new user
- **SSH port** (default: `2222`)
- **Backup SSH public key** (optional)

It will then run all hardening modules, install helper commands, and generate a security report.

## SSH Access After Hardening

### Primary method: SSH key

```bash
ssh -i ~/.ssh/id_ed25519 -p 2222 admin@your-server-ip
```

### Fallback method: Password + TOTP

If you lose your SSH key or need to connect from a new machine:

```bash
ssh -p 2222 admin@your-server-ip
# Enter password, then enter the 6-digit code from your authenticator app
```

## Helper Commands

After hardening, these commands are available on the server:

```bash
open-port 80          # Open TCP port 80
open-port 5432 tcp    # Open TCP port 5432
open-port 53 udp      # Open UDP port 53
close-port 80         # Close TCP port 80
list-ports            # Show all open ports and services
security-status       # Full security summary
```

## Recovery

| Scenario | What to do |
|----------|------------|
| Lost SSH key | Use password + TOTP from any machine |
| Lost phone (no authenticator) | Use the 5 emergency scratch codes saved during setup |
| Lost key + phone | Scratch codes, or use your VPS provider's console access |

Scratch codes are stored in `/home/<username>/.google_authenticator` on the server.

## What Gets Changed

The script modifies these files and services on your server:

| Area | Files / Services |
|------|-----------------|
| Users | Creates a new user in wheel group, `/etc/sudoers.d/<user>` |
| SSH | `/etc/ssh/sshd_config.d/99-hardening.conf`, backup of original config |
| Firewall | firewalld rules (custom SSH port only) |
| PAM | `/etc/pam.d/sshd` (adds google-authenticator) |
| TOTP | `/home/<user>/.google_authenticator` |
| Kernel | `/etc/sysctl.d/99-hardening.conf` |
| SELinux | Enforcing mode, custom SSH port context |
| Services | Disables postfix, rpcbind, cups |
| Updates | `/etc/dnf/automatic.conf`, dnf-automatic-install.timer |
| Fail2Ban | `/etc/fail2ban/jail.local` |
| AIDE | `/var/lib/aide/aide.db.gz`, `/etc/cron.d/aide-check` |
| Access | `/etc/cron.allow`, `/etc/at.allow`, USB storage blacklist |
| Logging | `/var/log/journal/` (persistent journald) |

## Uninstall

There is no automated uninstall. To reverse changes manually:

1. **SSH config**: Remove `/etc/ssh/sshd_config.d/99-hardening.conf`, restore backup
2. **Firewall**: `firewall-cmd --permanent --add-service=ssh && firewall-cmd --reload`
3. **Fail2Ban**: `systemctl disable --now fail2ban`
4. **TOTP**: Remove the PAM line from `/etc/pam.d/sshd`
5. **SELinux**: Change to permissive if needed: `setenforce 0`
6. **Kernel params**: Remove `/etc/sysctl.d/99-hardening.conf`
7. **Helper commands**: `rm /usr/local/bin/{open-port,close-port,list-ports,security-status}`

## License

MIT
