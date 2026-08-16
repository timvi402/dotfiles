# Omarchy 4.0 lock screen — YubiKey auth and the three-island surface

Port the illogical-impulse (ii) hardware-only lock screen onto Omarchy 4.0's
native Quickshell lock, as a user-owned shell plugin.

## Goal

Unlock the machine by touching a YubiKey, with fingerprint as the fallback and
a password behind a deliberate action — presented on the three-island surface
that ii drew, but themed from Omarchy's own tokens so it follows the active
theme.

## Why this is not currently possible

The 4.0 upgrade rewrote `~/.config/hypr/` from `.conf` to `.lua`. Two of the
orphaned files carried this feature:

- `autostart.conf` held `exec-once = uwsm-app -- qs -c ii -n -d`. The new
  `autostart.lua` is the pristine template, so the ii shell never starts.
- `bindings.conf` bound `SUPER+L` to `OMARCHY_LOCK_ONLY=true omarchy-system-lock`.
  The new `bindings.lua` is also pristine, so that binding is gone too.

`~/.local/bin/omarchy-system-lock` still shadows the stock script and still
tries `qs -c ii ipc call lock activate`. With ii not running, its `qs_lock_state`
probe fails and it falls through to `hyprlock` — which is the only reason the
YubiKey works at all today, via `/etc/pam.d/hyprlock`.

Omarchy 4.0 ships its own lock: a Quickshell `WlSessionLock` with separate
password and fingerprint PAM flows. It is a better foundation than ii's — it is
maintained, it is already wired into `omarchy-system-lock`, and it survives
updates. But it has **no u2f path whatsoever**. `grep -iE 'u2f|fido|yubi'` over
`plugins/lock/Service.qml` returns nothing. It knows two PAM services,
`omarchy-lock-password` and `omarchy-lock-fingerprint`, and that is all.

So the gap is not cosmetic. The native lock cannot authenticate the YubiKey,
and no amount of restyling changes that.

## Constraints

- Never edit `/usr/share/omarchy/`. Customisation goes through
  `omarchy plugin clone`, which copies into `~/.config/omarchy/plugins/`.
- A broken lock screen either locks the session out or leaves the machine
  unlocked. Every change must be verifiable without locking the screen.
- `/etc/pam.d/` needs root. Use `sudo` from an interactive terminal.
- The lock must keep following the Omarchy theme; nothing hardcoded.

## Scope

In scope: YubiKey (u2f) authentication in the lock, the hardware-prompt UX, and
the three-island surface.

Out of scope, tracked separately:

- The `bindings.conf` → `bindings.lua` port ("Part A"). Independent of this
  work, and needed regardless. It supplies `SUPER+L → omarchy-system-lock`,
  which this design assumes but does not deliver.
- Retiring `~/.local/bin/omarchy-system-lock`. Also Part A. Until it is retired
  it shadows the stock script and this plugin will not be reached.
- The orphaned `.conf` files, `hypridle.conf`, and the dotfiles repo tracking
  `.conf` while the live config is `.lua`.

## Decisions

**Clone the plugin rather than fork the shell.** `omarchy plugin clone omarchy.lock`
copies `lock/` to `~/.config/omarchy/plugins/timmy-xlent.lock/`. Two mechanics
make this the supported path rather than a workaround:

- `copy_plugin` takes its whole-directory branch when the manifest is named
  `manifest.json` (it is), so `LockView.qml` comes along and not just the
  `Service.qml` entry point.
- `PluginRegistry.qml:523-524` — for a non-widget kind, enabling the clone adds
  the source to `disabledPlugins[]`. `service` is a non-widget kind, so
  `omarchy.lock` is disabled automatically. Exactly one lock service runs.

The manifest records `clonedFrom: omarchy.lock`, which keeps IPC routed
(`PluginRegistry.qml:153`). `omarchy-shell lock lock` continues to reach the
clone, so `omarchy-system-lock` needs no change.

**A separate u2f PAM service, not a line in the password stack.** The rejected
alternative was `auth sufficient pam_u2f.so` inside `omarchy-lock-password`,
mirroring `/etc/pam.d/hyprlock`. Two lines, no QML — but it cannot express an
*armed* state, so the pulsing "Touch your YubiKey" island in Phase 2 would have
nothing to bind to, and a failed touch would count against that stack's
`pam_faillock deny=10`. A separate service also matches the split Omarchy
already chose for password vs. fingerprint.

**`required`, not `sufficient`.** `/etc/pam.d/hyprlock` uses `sufficient`
because it stacks u2f ahead of `include login` and needs to short-circuit. Here
the `PamContext` succeeding *is* the unlock, exactly as in
`omarchy-lock-fingerprint`, so `required` is correct.

**Omarchy tokens, ii geometry.** Keep ii's proportions — three 56px pills at
`radius: height/2`, same anchoring, same entrance animation — but source colours
from Omarchy's `Color`/`Style` singletons rather than porting ii's
`m3colors`/`Appearance`. The lock keeps tracking tokyo-night and every other
theme, and ii's `Appearance` singleton stays out of the plugin.

**Auth before chrome.** Phase 1 delivers working YubiKey unlock on 4.0's
existing centered field. Phase 2 replaces the surface. This ordering means the
islands are built against real state rather than a placeholder, and a PAM
problem is never debugged through a freshly rewritten lock screen.

**Power buttons act immediately.** Carried from the ii config
(`requirePasswordToPower: false`). Power, restart and sleep fire on a single
click from the locked screen, which is roughly what the physical power button
already permits.

## Current state on this machine

Verified, not assumed:

| Fact | Value |
|---|---|
| Omarchy | `4.0.0-1` |
| YubiKey detected | `/dev/hidraw1: vendor=0x1050, product=0x0407 (Yubico YubiKey OTP+FIDO+CCID)` |
| u2f enrollment | `/etc/fido2/fido2`, 401 bytes, owned by the user |
| `pam_u2f.so` | present, `/usr/lib/security/` |
| `fido2-token`, `fprintd-list` | both on PATH |
| `pamtester` | **missing** — needed for verification |
| Lock PAM files | not owned by any package (`pacman -Qo` errors) |
| PAM file management | only `install/user/first-run/setup-fingerprint.hook`, guarded by `[[ ! -f ]]` |

The last two rows matter: nothing in Omarchy manages a file named
`omarchy-lock-u2f`, so adding one is safe across updates.

The ii settings being reproduced, from `~/.config/illogical-impulse/config.json`:

```json
"lock": {
  "security":  { "hardwareOnly": true, "unlockKeyring": true, "requirePasswordToPower": false },
  "clock":     { "enable": true, "fontSize": 120, "fontWeight": 500, "showDate": true },
  "blur":      { "enable": true, "radius": 100, "extraZoom": 1.1 },
  "materialShapeChars": true
}
```

## Components

The clone is three files. Phase 1 touches two of them plus one root-owned file.

| File | Phase | Change |
|---|---|---|
| `/etc/pam.d/omarchy-lock-u2f` | 1 | new, root-owned |
| `plugins/timmy-xlent.lock/Service.qml` | 1 | add u2f context, detection, `primaryMethod` |
| `plugins/timmy-xlent.lock/LockView.qml` | 1 | hardware prompt on the existing field |
| `plugins/timmy-xlent.lock/LockView.qml` | 2 | three-island surface, clock, animation |
| `plugins/timmy-xlent.lock/manifest.json` | — | rewritten by the clone script; not edited |

## Phase 1 — authentication

### The PAM service

```
/etc/pam.d/omarchy-lock-u2f
#%PAM-1.0
auth       required   pam_u2f.so cue authfile=/etc/fido2/fido2
account    include    system-local-login
```

Shaped after `omarchy-lock-fingerprint`, which is the closest existing
analogue: a single-mechanism stack whose success is the unlock. `cue` prompts
for the touch. The `authfile` is the enrollment already in use by
`/etc/pam.d/hyprlock`, so no re-enrollment is needed.

### Service.qml

Add, alongside the existing `passwordPam` and `fingerprintPam`:

- `PamContext { id: u2fPam; config: "omarchy-lock-u2f"; user: root.userName }`,
  following the lifecycle the fingerprint context already uses — start when the
  lock becomes secure, abort on teardown, retry on failure while still locked.
- A `Process` running `fido2-token -L`, with a `Timer` polling it while locked.
  Presence is `stdout.includes("/dev/")`, matching ii's detection.
- `property bool yubikeyPresent` and
  `readonly property string primaryMethod` resolving `yubikey` → `fingerprint`
  → `password`.

The poll must be gated on `!u2fPam.active`. ii carries a comment about this:
an active u2f attempt already holds the device, and polling concurrently makes
`pam_u2f` sit on a busy token. Reproduce that gate.

Extend the `status()` IPC payload with `yubikey` and `primaryMethod`. This is
what makes Phase 1 verifiable without locking — see Verification.

### LockView.qml

Minimal for this phase. The existing centered field stays; the placeholder text
becomes the hardware prompt, driven by `primaryMethod`:

| `primaryMethod` | Prompt |
|---|---|
| `yubikey` | "Touch your YubiKey" |
| `fingerprint` | "Place your finger on the reader" |
| neither | "Insert your YubiKey" |

The password remains reachable by typing, as it is today. The deliberate-action
hiding of the password box (`hardwareOnly`) lands in Phase 2 with the islands.

## Phase 2 — the surface

Three pills anchored bottom-centre, animating in on scale and opacity, over a
blurred wallpaper and a neutral black dim. A large clock (120px, weight 500,
with date) centred at roughly `-6%` vertical offset.

ii's `Toolbar.qml` is not available to the plugin — it depends on ii's
`Appearance` and `StyledRectangularShadow`. The pill is rebuilt inside the
plugin as a plain `Rectangle` at `radius: height/2`, `implicitHeight: 56`,
padding 8, with its colour from Omarchy's surface tokens. That is the whole of
what ii's component contributes visually.

- **Left** — username (`account_circle`), keyboard layout (`keyboard_alt` +
  the Hyprland xkb layout code).
- **Main** — the hardware prompt: an icon (`security_key` / `fingerprint` /
  `lock`) pulsing 1.0↔0.4 on a 900ms loop while a device is armed, beside a
  two-line label. Falls back to the password field on keystroke or Esc.
- **Right** — battery, sleep, power, restart. Unguarded, per Decisions.

Plus the `fallbackHint` pill above the main island — "Type or press Esc to use
your password" — visible only while the password field is hidden.

ii's left island also carried an Fcitx systray. Dropped unless it turns out to
be in use; see Open questions.

## Verification

The point of this section is that neither phase requires locking the screen to
know whether it works.

**Before touching the shell**, validate the PAM stack in isolation:

```bash
omarchy pkg aur add pamtester    # AUR-only: aur/pamtester 0.1.2-4
pamtester omarchy-lock-u2f "$USER" authenticate
```

This exercises `pam_u2f` exactly as the lock will, in a terminal where a hang
is Ctrl-C rather than a lockout. Do not proceed until it succeeds with a touch
and fails cleanly without one.

**Phase 1**, after wiring:

```bash
omarchy-shell lock status | jq     # expect yubikey:true, primaryMethod:"yubikey"
```

Unplug the key and re-read: `primaryMethod` should fall to `fingerprint`. This
confirms detection and the resolution order without a lock.

**Phase 2**:

```bash
omarchy-shell lock preview         # renders LockView in a dismissible overlay
omarchy-shell lock hidePreview
```

`Service.qml:289-317` mounts a second `LockView` in a `PanelWindow` namespaced
`omarchy-lock-preview`, dismissed by click. The whole surface can be iterated
here without a session lock.

**First live lock**, once both phases pass the above: log in on a second TTY
(Ctrl+Alt+F2) first, so a failure is recoverable, then `omarchy-shell lock lock`.

## Risks

**Lockout.** The mitigation is the ordering above — `pamtester` before the
shell, `status` before a lock, `preview` before a live surface, a TTY open on
the first real lock. `hyprlock` stays installed as a floor; its PAM stack is
untouched by this work.

**pam_u2f contending for the device.** Handled by gating the detection poll on
`!u2fPam.active`.

**The clone drifts from upstream.** A cloned plugin does not receive updates to
`omarchy.lock`. Record the 4.0.0-1 baseline so the diff is recoverable when
upstream changes the lock. This is the standing cost of the approach and is
accepted.

**Nothing reaches the plugin while the local override exists.**
`~/.local/bin/omarchy-system-lock` precedes `/usr/share/omarchy/bin` on PATH.
Until Part A retires it, `SUPER+L` goes to ii-or-hyprlock and never to this
plugin. Phase 1 is not observable end-to-end until that happens.

## Open questions

1. Fcitx — is it in use? If not, the left island drops the systray.
2. `unlockKeyring` — ii unlocked the keyring with the typed password. In
   hardware-only mode there is no typed password, so the keyring may go
   unlocked on a YubiKey unlock. Check whether 4.0 handles this and whether it
   matters in practice.
3. Whether the password field should be hidden by default in Phase 2
   (ii's `hardwareOnly` posture) or remain visible. Deferred to Phase 2.

## Follow-ups

- Part A: port `bindings.conf` → `bindings.lua`, retire the local
  `omarchy-system-lock`. Blocks end-to-end use of this work.
- Track `~/.config/hypr/*.lua` and the plugin in the dotfiles repo; the repo
  currently tracks the superseded `.conf` files.
