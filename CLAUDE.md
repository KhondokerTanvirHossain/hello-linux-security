# CLAUDE.md — Project Instructions

## Overview

This is an AlmaLinux VM security hardening toolkit. It automates the process of
securing a fresh AlmaLinux virtual machine: creating a non-root sudo user,
locking down SSH, configuring the firewall, enabling SELinux, setting up
fail2ban, and installing helper utilities for ongoing management.

**Target OS:** AlmaLinux 8/9. May work on RHEL/Rocky Linux but not guaranteed.

## Project Structure

```
harden.sh              # Entry point — run as root on a fresh AlmaLinux VM
modules/
  common.sh            # Shared functions: logging, colored output, prompts, validation
  01-*.sh              # Numbered scripts executed in order; each sources common.sh
  02-*.sh
  ...
helpers/               # Utility scripts installed to /usr/local/bin/ on target VM
docs/
  plans/               # Design and implementation documents
```

- `harden.sh` is the single entry point. It sources and executes the numbered
  module scripts in `modules/` sequentially.
- Every module sources `modules/common.sh` for shared functionality.
- `helpers/` contains commands like `open-port`, `close-port`, etc. that are
  copied to `/usr/local/bin/` during setup. These are the intended way to manage
  the firewall after initial hardening.
- `docs/plans/` holds design docs and implementation plans.

## Coding Conventions

### Shell Standards

- All scripts use `#!/bin/bash` and `set -euo pipefail`.
- All modules are **idempotent** — safe to re-run without side effects.
- No hardcoded values. All configuration comes from interactive prompts or
  sensible defaults.
- The script must be run as root. It creates a non-root user with sudo access.

### Naming

- Functions are prefixed by module concern:
  - `fw_*` — firewall functions
  - `ssh_*` — SSH configuration functions
  - `user_*` — user management functions
  - `selinux_*` — SELinux functions
  - `f2b_*` — fail2ban functions
- Module files are numbered to enforce execution order: `01-users.sh`,
  `02-ssh.sh`, etc.

### Logging

Use the logging functions from `modules/common.sh`:

- `log_info` — informational messages (blue)
- `log_warn` — warnings (yellow)
- `log_error` — errors (red)
- `log_success` — success confirmations (green)

Do not use raw `echo` for user-facing output. Always use the logging helpers.

## Key Design Decisions

### SSH Authentication

Two modes, chosen interactively during setup:

1. **Key-based authentication (primary)** — password auth disabled entirely.
2. **Password + TOTP (fallback)** — for environments where key distribution is
   impractical. Uses google-authenticator for the TOTP second factor.

See `docs/plans/` for the full design rationale.

### SSH Restart Safety

**sshd is NOT restarted until all configuration is written and the firewall is
ready.** This prevents lockouts where a config change takes effect before the
new port is reachable.

### Firewall Management

After initial setup, use the helper commands installed in `/usr/local/bin/`:

- `open-port` — open a port in firewalld
- `close-port` — close a port in firewalld

Do not edit firewalld rules directly unless necessary.

## Common Pitfalls

1. **Never restart sshd without confirming the new port is open in the firewall
   first.** This is the single most common cause of lockouts.

2. **SELinux must be told about non-standard SSH ports.** Use `semanage port`
   to register custom SSH ports before restarting sshd, or SELinux will block
   the connection.

3. **google-authenticator setup is per-user, not system-wide.** Each user who
   needs TOTP must run `google-authenticator` individually under their own
   account.

4. **fail2ban must target the custom SSH port, not the default 22.** If the SSH
   port is changed, the fail2ban jail configuration must reference the new port
   or it will silently do nothing.
