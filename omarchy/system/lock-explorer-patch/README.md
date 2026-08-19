# lock-explorer local patch

`io.github.sirjul1337.lock-explorer` is a third-party Omarchy shell plugin
installed into `~/.config/omarchy/plugins/`. It is **not** stow-managed — the
plugin manager owns that directory and will overwrite it on update, taking
these changes with it silently.

Patched against **version 1.2.1**.
Pristine `Service.qml` sha256: `2ff906fc76df07f8d664db754c05ea5f9b62fc6f5ee42401066aa0a60c1f4f09`

## What the patch does, and why

**1. YubiKey (u2f) authentication — `Service.qml`.** The plugin is
`clonedFrom: omarchy.lock` taken from upstream, which has no u2f support at
all: it knows only `omarchy-lock-password` and `omarchy-lock-fingerprint`.
Installing it therefore *silently disabled YubiKey unlock* — the lock kept
working, so nothing looked broken, but the key stopped being an option.

The patch ports the u2f flow: a third `PamContext` on `omarchy-lock-u2f`, a
`fido2-token -L` presence poll, `primaryMethod` resolving yubikey →
fingerprint → password, and three extra fields on the `status()` IPC.

Two values in it are measured, not chosen — do not "tidy" them:

- `u2fRetryTimer.interval: 2000`. At 250ms (the value the sibling fingerprint
  retry uses) the retry lands on a FIDO device `pam_u2f` has not yet released
  after a timeout, giving ~9 wasted subprocess spawns over ~3s during which a
  real touch does nothing. `fprintd` serialises access; `pam_u2f` opens
  `/dev/hidraw*` directly.
- The `!u2fPam.active` guard on the presence poll, for the same reason.

**2. Display blank delay — `Service.qml`.** `idleBlankTimer.interval` raised
from upstream's `5000` to `60000`. Local preference, not a bug fix.

**3. Hardware prompt in the design — `LockHost.qml`, `designs/DesignBase.qml`,
`designs/Editorial.qml`.** `primaryMethod` and `u2fConfigured` are threaded
from the service through `LockHost` and `DesignBase` so any design can read
them; `Editorial.qml`'s upper-right corner then shows what the machine is
actually waiting for instead of a static "FINGERPRINT READY".

The properties live on `DesignBase`, not `Editorial`, so switching designs
later does not break the plumbing.

## Requirements

`/etc/pam.d/omarchy-lock-u2f` must exist (root:root 644). It is recorded at
`omarchy/system/etc/pam.d/omarchy-lock-u2f` in this repo — see that
directory's README, including the note that `/etc/fido2/fido2` must be
root-owned.

## Reapplying after a plugin update

```bash
cd ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer
patch -p1 --dry-run < ~/dotfiles/omarchy/system/lock-explorer-patch/local-changes.patch
patch -p1           < ~/dotfiles/omarchy/system/lock-explorer-patch/local-changes.patch
omarchy restart shell     # keepLoaded: hot reload does NOT re-instantiate the service
```

If the dry run rejects hunks, upstream moved. The u2f hunks were written
against the upstream `omarchy.lock` structure and key off
`fingerprintPam` / `startFingerprint` / `resetAuthenticationState` /
`onSecureStateChanged` / `fingerprintCheckProc` / `Component.onCompleted` /
`status()`, so port them to wherever those moved.

## Verifying it took

```bash
omarchy-shell lock status | jq '{u2fPam, yubikey, primaryMethod}'
```

Expect `u2fPam: true`, `yubikey: true` (with the key inserted), and
`primaryMethod: "yubikey"`. Those three fields exist **only** in the patched
code — if they come back `null`, the patch is not applied, whatever else looks
right. Then press SUPER+L and touch the key.

## Only one lock service may be enabled

`omarchy.lock`, `timmy-xlent.lock` and this plugin each declare a
`WlSessionLock` and each claim `IpcHandler target: "lock"`. Two enabled at once
means whichever wins the IPC is a coin toss — which is exactly how YubiKey
unlock broke without any visible symptom.

Note the trap: disabling a *clone* makes `PluginRegistry.restoreCloneSource`
re-enable its source, so disabling `timmy-xlent.lock` silently re-enables
`omarchy.lock`. Check after any change:

```bash
omarchy-plugin-list --json | jq -r '.[] | select(.id|test("lock")) | "\(.id) \(.enabled)"'
```
