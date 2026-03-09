# AlmaLinux Security Hardening Script — Design Document

**Date:** 2026-03-10
**Status:** Approved

## Purpose

A clone-and-run security hardening toolkit for freshly provisioned AlmaLinux VMs with public IPs. Balances strong security with day-to-day usability for an MVP/test server that may run web apps, databases, Docker, or any combination.

## Design Principles

1. **Security should not bottleneck future work** — helper commands make port management trivial
2. **No lockout risk** — dual SSH auth (key primary, password+TOTP fallback), pre-flight checks, phased rollout
3. **Idempotent modules** — safe to re-run any section
4. **Interactive setup** — prompts with sane defaults, no config files to edit

## Prerequisites (User Does Before Running Script)

1. SSH into VM as root with password
2. Run `ssh-copy-id` to copy SSH public key to root
3. Verify key-based login works
4. Clone this repo and run `./harden.sh`

## Repo Structure

```
hello-linux-security/
├── CLAUDE.md                  # Project instructions for Claude
├── README.md                  # Usage docs
├── harden.sh                  # Entry point
├── modules/
│   ├── 01-user-setup.sh       # Create user, copy SSH keys
│   ├── 02-ssh-hardening.sh    # SSH config, port change, key+TOTP auth
│   ├── 03-firewall.sh         # Close all ports, open only SSH
│   ├── 04-totp-setup.sh       # Google Authenticator install + config
│   ├── 05-system-hardening.sh # Kernel, SELinux, disable services, cron
│   ├── 06-auto-updates.sh     # dnf-automatic
│   ├── 07-fail2ban.sh         # Brute force protection
│   ├── 08-monitoring.sh       # AIDE, log config
│   └── common.sh              # Shared functions (logging, colors, prompts)
├── helpers/
│   ├── open-port              # /usr/local/bin/open-port <port> [tcp|udp]
│   ├── close-port             # /usr/local/bin/close-port <port> [tcp|udp]
│   ├── list-ports             # /usr/local/bin/list-ports
│   └── security-status        # Shows enforcement summary
└── docs/
    └── plans/
```

## SSH Authentication Design

Two paths, either accepted by sshd:

| Method | When Used | What's Needed |
|--------|-----------|---------------|
| SSH Key | Daily use (primary) | Private key on your machine |
| Password + TOTP | Emergency / new machine | Password AND authenticator code |

sshd_config line: `AuthenticationMethods publickey keyboard-interactive:pam`

### Key Recovery Paths

| Scenario | Recovery |
|----------|----------|
| Lost SSH key | Password + TOTP from any machine |
| Lost phone | 5 emergency scratch codes (saved during setup) |
| Lost key + phone | Scratch codes, or VPS provider console |

## Script Execution Flow

### Phase 0: Pre-flight
- Must be root
- Must be AlmaLinux
- Check internet (needed for package installs)
- Warn if no SSH key in root's authorized_keys

### Phase 1: Interactive Prompts
- Username (default: admin)
- Password (hidden input)
- SSH port (default: 2222)
- Optional backup SSH public key

### Phase 2: Execute Modules (01-08)
- Each module logs what it does
- Module 04 (TOTP) pauses for QR code scanning
- sshd is NOT restarted until all config is ready

### Phase 3: Install Helpers
- Copy helper scripts to /usr/local/bin/
- Make executable

### Phase 4: Generate Report
- Write ~/security-report.txt
- Contents: username, SSH port, open ports, scratch codes location, helper cheat sheet

### Phase 5: Verification
- Verify user exists with sudo
- Verify firewall rules
- Verify fail2ban running
- Verify SELinux enforcing
- Print connection instructions

## Helper Commands

```bash
open-port 80          # Open TCP port 80
open-port 5432 tcp    # Explicit protocol
close-port 80         # Close TCP port 80
list-ports            # Show all open ports
security-status       # Full security summary
```

## Security Layers Summary

| Layer | Protection |
|-------|-----------|
| SSH | Non-standard port, key or password+TOTP, no root login |
| Firewall | All ports closed except SSH, helpers to manage |
| Brute force | Fail2Ban bans after 3 attempts (24h ban) |
| OS | Auto-updates, SELinux enforcing, kernel hardening |
| Monitoring | AIDE file integrity, journal logging |
| Access | sudo with 5min timeout, cron/at restricted |

## What the Script Does NOT Do

- Does not disable VPS provider console access (that's your recovery path)
- Does not set up TLS/certificates (that's app-specific)
- Does not configure application-level firewalls (Docker iptables, etc.)
- Does not manage users beyond the initial one
