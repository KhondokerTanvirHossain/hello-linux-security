# AlmaLinux Security Hardening Script — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a clone-and-run interactive security hardening toolkit for AlmaLinux VMs that balances strong security with day-to-day usability.

**Architecture:** A single entry-point `harden.sh` sources `modules/common.sh` for shared functions, then runs numbered module scripts sequentially. Helper scripts are installed to `/usr/local/bin/` for daily port management. All modules are idempotent.

**Tech Stack:** Bash (POSIX-compatible where possible), firewalld, fail2ban, google-authenticator-libpam, AIDE, dnf-automatic, SELinux, PAM.

**Design doc:** `docs/plans/2026-03-10-security-hardening-design.md`

---

### Task 1: CLAUDE.md — Project Instructions

**Files:**
- Create: `CLAUDE.md`

**Step 1: Write CLAUDE.md**

```markdown
# Hello Linux Security

AlmaLinux VM security hardening toolkit.

## Project Structure

- `harden.sh` — Entry point. Run as root on a fresh AlmaLinux VM.
- `modules/` — Numbered scripts executed in order by harden.sh. Each sources common.sh.
- `modules/common.sh` — Shared functions: logging, colored output, prompts, validation.
- `helpers/` — Utility scripts installed to /usr/local/bin/ on the target VM.
- `docs/plans/` — Design and implementation docs.

## Conventions

- All scripts use `#!/bin/bash` and `set -euo pipefail`.
- Functions prefixed by module concern: `fw_*` for firewall, `ssh_*` for SSH, etc.
- Logging via `log_info`, `log_warn`, `log_error`, `log_success` from common.sh.
- All modules are idempotent — safe to re-run.
- No hardcoded values — all config comes from interactive prompts or defaults.
- Test on AlmaLinux 8/9. May work on RHEL/Rocky but not guaranteed.

## Key Design Decisions

- SSH auth: key (primary) OR password+TOTP (fallback). See design doc.
- sshd is NOT restarted until all config is written and firewall is ready.
- Script must be run as root. It creates a non-root user with sudo.
- Helper commands (open-port, close-port, etc.) are the intended way to manage firewall after setup.

## Common Pitfalls

- Never restart sshd without confirming the new port is open in firewall first.
- SELinux must be told about non-standard SSH ports via semanage.
- google-authenticator setup is per-user, not system-wide.
- fail2ban must target the custom SSH port, not default 22.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with project conventions"
```

---

### Task 2: modules/common.sh — Shared Functions

**Files:**
- Create: `modules/common.sh`

**Step 1: Write common.sh**

This is the foundation. All modules source this file. It provides:
- Color constants (RED, GREEN, YELLOW, BLUE, NC)
- `log_info`, `log_warn`, `log_error`, `log_success` — colored prefixed output
- `prompt_input "message" "default"` — interactive input with default value
- `prompt_password "message"` — hidden input for passwords
- `prompt_confirm "message"` — yes/no confirmation, returns 0/1
- `check_root` — exit if not root
- `check_alma` — exit if not AlmaLinux
- `check_internet` — exit if no connectivity
- `section_header "title"` — prints a visible section divider
- `SCRIPT_DIR` variable — resolved directory of harden.sh for sourcing modules

Key implementation details:
- Colors: `RED='\033[0;31m'` etc., with `NC='\033[0m'` reset
- `log_info` prints `[INFO] message` in blue
- `log_warn` prints `[WARN] message` in yellow
- `log_error` prints `[ERROR] message` in red
- `log_success` prints `[OK] message` in green
- `prompt_input` uses `read -rp` with default shown in brackets
- `prompt_password` uses `read -rsp` (silent)
- `check_alma` reads `/etc/os-release` and checks for `AlmaLinux`
- `check_internet` pings `1.1.1.1` once with 5s timeout
- All functions use `echo -e` for color support

**Step 2: Verify syntax**

```bash
bash -n modules/common.sh
```

Expected: no output (clean syntax)

**Step 3: Commit**

```bash
git add modules/common.sh
git commit -m "feat: add common.sh shared functions library"
```

---

### Task 3: harden.sh — Entry Point

**Files:**
- Create: `harden.sh`

**Step 1: Write harden.sh**

The entry point script that:
1. Resolves its own directory (`SCRIPT_DIR`)
2. Sources `modules/common.sh`
3. Runs pre-flight checks (root, AlmaLinux, internet, SSH key warning)
4. Collects interactive input (username, password, SSH port, optional backup key)
5. Exports collected variables for modules to use
6. Runs each module in order: `source "$SCRIPT_DIR/modules/01-user-setup.sh"` through `08`
7. Installs helper scripts to `/usr/local/bin/`
8. Generates `~/security-report.txt` (in new user's home)
9. Runs verification checks
10. Prints final connection instructions

Key implementation details:
- Starts with `#!/bin/bash` and `set -euo pipefail`
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- Pre-flight: calls `check_root`, `check_alma`, `check_internet`
- SSH key check: `if [[ ! -s /root/.ssh/authorized_keys ]]; then log_warn "No SSH key found..."` with confirm prompt
- Interactive prompts use `prompt_input` and `prompt_password` from common.sh
- Exports: `NEW_USER`, `NEW_USER_PASS`, `SSH_PORT`, `BACKUP_KEY` (may be empty)
- Module execution: loops through `modules/[0-9]*.sh` in sorted order, sources each
- Helper install: copies `helpers/*` to `/usr/local/bin/`, chmod +x, replaces `{{SSH_PORT}}` placeholder with actual port
- Report generation: writes `~/security-report.txt` to `/home/$NEW_USER/`
- Verification: checks user exists, firewall rules, fail2ban status, SELinux mode
- Final output: prints SSH command for new terminal test

**Step 2: Make executable and verify syntax**

```bash
chmod +x harden.sh
bash -n harden.sh
```

Expected: no output (clean syntax)

**Step 3: Commit**

```bash
git add harden.sh
git commit -m "feat: add harden.sh entry point with interactive prompts"
```

---

### Task 4: modules/01-user-setup.sh — Create User

**Files:**
- Create: `modules/01-user-setup.sh`

**Step 1: Write module**

This module:
1. Creates the user with `useradd -m -s /bin/bash "$NEW_USER"`
2. Sets the password with `echo "$NEW_USER:$NEW_USER_PASS" | chpasswd`
3. Adds to wheel group: `usermod -aG wheel "$NEW_USER"`
4. Copies root's SSH authorized_keys to new user's `.ssh/`
5. If `BACKUP_KEY` is set, appends it to authorized_keys
6. Sets correct ownership and permissions (700 for .ssh, 600 for authorized_keys)
7. Configures sudo timeout: adds `Defaults timestamp_timeout=5` to `/etc/sudoers.d/$NEW_USER`

Key details:
- Check if user already exists before creating (idempotent)
- `mkdir -p /home/$NEW_USER/.ssh`
- `cp /root/.ssh/authorized_keys /home/$NEW_USER/.ssh/authorized_keys`
- `chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh`
- Validate sudoers file with `visudo -cf` before placing it

**Step 2: Verify syntax**

```bash
bash -n modules/01-user-setup.sh
```

**Step 3: Commit**

```bash
git add modules/01-user-setup.sh
git commit -m "feat: add user setup module"
```

---

### Task 5: modules/02-ssh-hardening.sh — SSH Config

**Files:**
- Create: `modules/02-ssh-hardening.sh`

**Step 1: Write module**

This module:
1. Backs up current sshd_config: `cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)`
2. Writes hardened sshd_config settings to `/etc/ssh/sshd_config.d/99-hardening.conf` (drop-in, cleaner than editing main file)
3. Does NOT restart sshd yet (that happens after firewall is ready, in harden.sh)

The drop-in config (`99-hardening.conf`) contains:
```
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthenticationMethods publickey keyboard-interactive:pam
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $NEW_USER
X11Forwarding no
PermitEmptyPasswords no
LoginGraceTime 30
AllowAgentForwarding no
AllowTcpForwarding no
```

Note: `PasswordAuthentication yes` is required because the TOTP fallback uses keyboard-interactive which goes through PAM. PAM handles the password+TOTP flow. The `AuthenticationMethods` line ensures you need BOTH password and TOTP for the non-key path.

Key details:
- Uses drop-in dir `/etc/ssh/sshd_config.d/` (supported on AlmaLinux 8+)
- Tells SELinux about the new port: `semanage port -a -t ssh_port_t -p tcp $SSH_PORT` (or `-m` if already exists)
- Install `policycoreutils-python-utils` if semanage not available

**Step 2: Verify syntax**

```bash
bash -n modules/02-ssh-hardening.sh
```

**Step 3: Commit**

```bash
git add modules/02-ssh-hardening.sh
git commit -m "feat: add SSH hardening module"
```

---

### Task 6: modules/03-firewall.sh — Lock Down Firewall

**Files:**
- Create: `modules/03-firewall.sh`

**Step 1: Write module**

This module:
1. Ensures firewalld is installed and running
2. Removes all default services: ssh, cockpit, dhcpv6-client
3. Adds only the custom SSH port: `firewall-cmd --permanent --add-port=$SSH_PORT/tcp`
4. Reloads firewall
5. Verifies only the SSH port is open

Key details:
- `firewall-cmd --permanent --remove-service=ssh` (remove default ssh)
- `firewall-cmd --permanent --remove-service=cockpit`
- `firewall-cmd --permanent --remove-service=dhcpv6-client`
- After reload, verify with `firewall-cmd --list-all`
- Log the final firewall state

**Step 2: Verify syntax**

```bash
bash -n modules/03-firewall.sh
```

**Step 3: Commit**

```bash
git add modules/03-firewall.sh
git commit -m "feat: add firewall lockdown module"
```

---

### Task 7: modules/04-totp-setup.sh — Google Authenticator

**Files:**
- Create: `modules/04-totp-setup.sh`

**Step 1: Write module**

This module:
1. Installs `epel-release` then `google-authenticator`
2. Configures PAM for SSH: adds `auth required pam_google_authenticator.so nullok` to `/etc/pam.d/sshd`
3. Runs `google-authenticator` as the new user with recommended flags
4. PAUSES for user to scan QR code
5. Saves emergency scratch codes location to a variable for the report

Key details:
- `dnf install -y epel-release && dnf install -y google-authenticator`
- PAM config: insert `auth required pam_google_authenticator.so nullok` at the top of `/etc/pam.d/sshd`
  - `nullok` means users without TOTP configured can still login (only affects key-based for us)
- Run authenticator as user: `su - "$NEW_USER" -c "google-authenticator -t -d -f -r 3 -R 30 -w 3"`
  - `-t` time-based, `-d` disallow reuse, `-f` force write, `-r 3 -R 30` rate limit, `-w 3` window size
- The above prints QR code + secret + scratch codes to terminal
- After QR display: `prompt_confirm "Have you scanned the QR code and saved the scratch codes?"`
- Also needs `ChallengeResponseAuthentication yes` in sshd config (handled by module 02)

**Step 2: Verify syntax**

```bash
bash -n modules/04-totp-setup.sh
```

**Step 3: Commit**

```bash
git add modules/04-totp-setup.sh
git commit -m "feat: add TOTP setup module with Google Authenticator"
```

---

### Task 8: modules/05-system-hardening.sh — Kernel, SELinux, Services

**Files:**
- Create: `modules/05-system-hardening.sh`

**Step 1: Write module**

This module applies three categories of hardening:

**Kernel parameters** — writes `/etc/sysctl.d/99-hardening.conf`:
- `net.ipv4.ip_forward = 0` (disable IP forwarding)
- `net.ipv4.conf.all.accept_redirects = 0`
- `net.ipv4.conf.default.accept_redirects = 0`
- `net.ipv4.conf.all.accept_source_route = 0`
- `net.ipv4.tcp_syncookies = 1` (SYN flood protection)
- `net.ipv4.conf.all.log_martians = 1`
- `net.ipv4.icmp_echo_ignore_all = 1` (hide from ping)
- `fs.suid_dumpable = 0` (disable core dumps for setuid)
- Applies with `sysctl -p /etc/sysctl.d/99-hardening.conf`

**SELinux** — verify enforcing:
- Check `getenforce`, if not `Enforcing`, set it and update `/etc/selinux/config`

**Disable unused services:**
- Disable: postfix, rpcbind, cups (check if they exist first)
- `systemctl disable --now $service 2>/dev/null || true`

**Lock down cron/at:**
- Write `$NEW_USER` to `/etc/cron.allow` and `/etc/at.allow`

**Disable USB storage** (remote VM):
- `echo "blacklist usb-storage" > /etc/modprobe.d/disable-usb.conf`

**Core dumps:**
- Append `* hard core 0` to `/etc/security/limits.conf` (if not already present)

**Password policy:**
- `dnf install -y libpwquality`
- Set `minlen = 14`, `dcredit = -1`, `ucredit = -1`, `lcredit = -1`, `ocredit = -1` in `/etc/security/pwquality.conf`

**Step 2: Verify syntax**

```bash
bash -n modules/05-system-hardening.sh
```

**Step 3: Commit**

```bash
git add modules/05-system-hardening.sh
git commit -m "feat: add system hardening module"
```

---

### Task 9: modules/06-auto-updates.sh — Automatic Updates

**Files:**
- Create: `modules/06-auto-updates.sh`

**Step 1: Write module**

This module:
1. Installs `dnf-automatic`: `dnf install -y dnf-automatic`
2. Configures `/etc/dnf/automatic.conf`:
   - `apply_updates = yes` (default is download only — must change this)
3. Enables the timer: `systemctl enable --now dnf-automatic-install.timer`

Key detail: The timer name is `dnf-automatic-install.timer` (not `dnf-automatic.timer`) — the install variant applies updates.

**Step 2: Verify syntax**

```bash
bash -n modules/06-auto-updates.sh
```

**Step 3: Commit**

```bash
git add modules/06-auto-updates.sh
git commit -m "feat: add automatic updates module"
```

---

### Task 10: modules/07-fail2ban.sh — Brute Force Protection

**Files:**
- Create: `modules/07-fail2ban.sh`

**Step 1: Write module**

This module:
1. Installs: `dnf install -y epel-release fail2ban` (epel may already be installed from TOTP step)
2. Writes `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/secure
maxretry = 3
bantime = 86400
```

3. Enables and starts: `systemctl enable --now fail2ban`
4. Verifies: `fail2ban-client status sshd`

Key detail: Uses default `banaction` (don't specify `firewallcmd-rich-rules` or `firewallcmd-ipset` — let fail2ban auto-detect based on what's installed). The port must match `$SSH_PORT`.

**Step 2: Verify syntax**

```bash
bash -n modules/07-fail2ban.sh
```

**Step 3: Commit**

```bash
git add modules/07-fail2ban.sh
git commit -m "feat: add fail2ban brute force protection module"
```

---

### Task 11: modules/08-monitoring.sh — AIDE & Logging

**Files:**
- Create: `modules/08-monitoring.sh`

**Step 1: Write module**

This module:

**AIDE (file integrity monitoring):**
1. Install: `dnf install -y aide`
2. Initialize: `aide --init`
3. Move DB: `mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz`
4. Add daily cron: write `/etc/cron.d/aide-check` with `0 3 * * * root /usr/sbin/aide --check > /var/log/aide-check.log 2>&1`

**Journal persistence:**
1. `mkdir -p /var/log/journal`
2. `systemctl restart systemd-journald`

**NTP (clock accuracy for TOTP):**
1. Ensure chronyd is running: `systemctl enable --now chronyd`

**Step 2: Verify syntax**

```bash
bash -n modules/08-monitoring.sh
```

**Step 3: Commit**

```bash
git add modules/08-monitoring.sh
git commit -m "feat: add monitoring module with AIDE and logging"
```

---

### Task 12: helpers/ — Port Management & Status Scripts

**Files:**
- Create: `helpers/open-port`
- Create: `helpers/close-port`
- Create: `helpers/list-ports`
- Create: `helpers/security-status`

**Step 1: Write open-port**

Usage: `open-port <port> [tcp|udp]` (default: tcp)
- Validates port is a number 1-65535
- Runs `sudo firewall-cmd --permanent --add-port=$PORT/$PROTO && sudo firewall-cmd --reload`
- Prints confirmation with current open ports

**Step 2: Write close-port**

Usage: `close-port <port> [tcp|udp]` (default: tcp)
- Safety check: refuses to close SSH port (`{{SSH_PORT}}` — replaced during install)
- Runs `sudo firewall-cmd --permanent --remove-port=$PORT/$PROTO && sudo firewall-cmd --reload`
- Prints confirmation

**Step 3: Write list-ports**

Usage: `list-ports`
- Runs `sudo firewall-cmd --list-ports` and `sudo firewall-cmd --list-services`
- Pretty-prints the results

**Step 4: Write security-status**

Usage: `security-status`
- Shows: SSH port, open ports, fail2ban status, SELinux status, last AIDE check, uptime, pending updates count
- Color-coded: green for good, red for issues

**Step 5: Make all executable and verify syntax**

```bash
chmod +x helpers/*
for f in helpers/*; do bash -n "$f"; done
```

**Step 6: Commit**

```bash
git add helpers/
git commit -m "feat: add helper scripts for port management and status"
```

---

### Task 13: README.md — User Documentation

**Files:**
- Modify: `README.md`

**Step 1: Write README**

Sections:
1. **Title + one-line description**
2. **What This Does** — bullet list of security layers applied
3. **Prerequisites** — SSH key copied, root access, AlmaLinux
4. **Quick Start** — 4-step clone-and-run instructions
5. **SSH Access After Hardening** — key-based and TOTP fallback examples
6. **Helper Commands** — open-port, close-port, list-ports, security-status with examples
7. **Recovery** — what to do if you lose your key, phone, or both
8. **What Gets Changed** — explicit list of files modified on the server
9. **Uninstall** — how to reverse changes (manual steps)

Keep it practical and direct. No marketing language.

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add comprehensive README with usage instructions"
```

---

### Task 14: Integration Test — Verify All Modules Load

**Step 1: Verify all scripts have valid bash syntax**

```bash
for f in harden.sh modules/*.sh helpers/*; do
  echo "Checking $f..."
  bash -n "$f" && echo "  OK" || echo "  FAIL"
done
```

Expected: all OK

**Step 2: Verify all modules are sourced by harden.sh**

```bash
grep -c 'source.*modules/' harden.sh
```

Expected: 8 (one per module, excluding common.sh which is sourced separately)

**Step 3: Verify helpers have no hardcoded ports remaining**

```bash
grep -r '{{SSH_PORT}}' helpers/
```

Expected: should find the placeholder in close-port (the safety check). harden.sh replaces this during install.

**Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: integration fixes from syntax verification"
```

---

## Execution Summary

| Task | What | Files |
|------|------|-------|
| 1 | CLAUDE.md | `CLAUDE.md` |
| 2 | Common functions | `modules/common.sh` |
| 3 | Entry point | `harden.sh` |
| 4 | User setup | `modules/01-user-setup.sh` |
| 5 | SSH hardening | `modules/02-ssh-hardening.sh` |
| 6 | Firewall | `modules/03-firewall.sh` |
| 7 | TOTP setup | `modules/04-totp-setup.sh` |
| 8 | System hardening | `modules/05-system-hardening.sh` |
| 9 | Auto updates | `modules/06-auto-updates.sh` |
| 10 | Fail2ban | `modules/07-fail2ban.sh` |
| 11 | Monitoring | `modules/08-monitoring.sh` |
| 12 | Helper scripts | `helpers/*` |
| 13 | README | `README.md` |
| 14 | Integration check | Verify everything |

Tasks 1-3 must be sequential (dependencies). Tasks 4-11 can be parallelized (independent modules). Tasks 12-14 depend on earlier tasks.
