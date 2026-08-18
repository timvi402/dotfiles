# Root-owned files, recorded not stowed

These mirror files that live outside `$HOME` and are owned by root, so
stow cannot manage them (`.stow-local-ignore` excludes this directory).
They are here so a rebuild can restore them by hand.

| File | Install to | Notes |
|---|---|---|
| `etc/pam.d/omarchy-lock-u2f` | `/etc/pam.d/omarchy-lock-u2f` | mode 644, root:root. The u2f PAM stack the Omarchy lock plugin authenticates against. |

Install:

```bash
pkexec install -m 644 -o root -g root \
  system/etc/pam.d/omarchy-lock-u2f /etc/pam.d/omarchy-lock-u2f
```

The stack reads `/etc/fido2/fido2` for the enrollment. That file must be
**root-owned** — it is `sufficient` for `sudo` and `polkit`, so a
user-writable copy lets any process running as you rewrite the terms of
its own privilege escalation:

```bash
pkexec chown root:root /etc/fido2/fido2   # mode 644 is correct; pam_u2f only reads it
```
