# Lock screen Phase 2 — the island surface

Replace Omarchy 4.0's centered password field with the island surface ii drew,
themed from Omarchy's own tokens.

**Parent spec:** `2026-08-17-omarchy-lock-yubikey-port-design.md`. Phase 1
(YubiKey authentication) is implemented and verified; this phase changes only
what the lock looks like, not how it authenticates.

## Goal

A lock screen that says what the machine is waiting for and offers the session
controls ii put there, without dragging ii's design system into the plugin.

## What changed from the parent spec's sketch

The parent describes three islands. Exploring the machine cut that to two.

**The left island is dropped.** It carried the username and the keyboard
layout. `hyprctl devices` reports exactly one configured layout (`se`), so the
layout indicator can never change, and the username is the only user on the
machine. It was a pill rendering two invariants. Restoring it is easy if a
second layout ever appears.

That also resolves the parent's **open question 1 (Fcitx)**: the systray it
would have lived in is gone with the island. No decision needed.

**Open question 3 (hiding the password field) is resolved: yes**, hidden behind
a deliberate action, matching ii's `hardwareOnly` posture. See *Password
reveal*.

**The fingerprint prompt is reworded** from ii's "Place your finger on the
reader" to "Scan your fingerprint". The two-line label has room for the longer
string, but the short form matches "Touch your YubiKey" in register and length.
This closes the eliding-prompt item deferred from Phase 1.

## Decisions

**Build fresh against Omarchy's tokens; use ii only for geometry.** The
rejected alternative was porting ii's `LockSurface.qml` across. It is 26KB and
depends on roughly fifteen ii components — `Appearance`, `StyledText`,
`MaterialSymbol`, `Toolbar`, `ToolbarButton`, `ToolbarTextField`,
`PasswordChars`, `ClockText`, `ErrorShakeAnimation`, `SystemInfo`,
`HyprlandXkb`, `Config`, `Session`, `GlobalStates`, `Translation`. Porting or
stubbing all of that would import ii's design system wholesale, contradicting
the parent spec's "Omarchy tokens, not ii's `m3colors`" decision. Taking the
numbers instead costs about a third of the code and inherits Omarchy's theming.

**Inline `component` declarations, not sibling QML files.** No first-party
Omarchy plugin carries a `.qml` file beyond its entry points — they ship `.js`
models (`MenuModel.js`, `BatteryModel.js`) and nothing else. Whether the plugin
loader resolves sibling components is therefore untested, and a lock screen is
the wrong place to find out. QML 6's `component Name: Item {}` gives real units
inside one file, which is what ii's own `LockSurface.qml` does for
`IconAndTextPair` and `PasswordGuardedIconToolbarButton`.

**Ship in two stages.** Islands and password reveal first, entrance animation
second, as separate commits. A misbehaving animation can then be reverted
without touching a working lock.

**Power buttons act immediately**, carried from the parent spec
(`requirePasswordToPower: false` in the ii config). One click from the locked
screen fires the action, which is roughly what the physical power button
already permits.

## Layout

The main island stays horizontally centered — it is where the eye goes — with
the session island anchored to its right edge. This is ii's geometry with the
left pill removed; the composition is deliberately asymmetric rather than
re-centered as a pair.

```
                          07:41
                    Monday, 18 August


          ╭──────────────────────────────────────╮
          │  Type or press Esc to use password   │   hint: only while field hidden
          ╰──────────────────────────────────────╯

    ╭─────────────────────────────────╮  ╭─────────────────────╮
    │  󰌆  Touch your YubiKey          │  │  󰁹 87  󰤄  󰐥  󰜉   │
    │      or scan your fingerprint   │  ╰─────────────────────╯
    ╰─────────────────────────────────╯
```

Geometry, taken from ii:

| Property | Value |
|---|---|
| Pill height | `implicitHeight: 56` |
| Pill radius | `height / 2` |
| Pill padding | 8 |
| Gap between pills | 10 |
| Distance from bottom | 20 |
| Clock size / weight | 120px, 500 |
| Clock vertical offset | `-parent.height * 0.06` |
| Pulse | 1.0 ↔ 0.4, 900ms each way, `Easing.InOutQuad` |

Colours come from `Color.lock.*` and sizes from `Style.font.*`, so the surface
follows the active Omarchy theme.

## Components

Five inline declarations in `LockView.qml`:

| Component | Responsibility |
|---|---|
| `Pill` | `Rectangle`, `radius: height/2`, surface token, drop shadow |
| `HardwarePrompt` | glyph plus two-line label, driven by `primaryMethod` |
| `SessionControls` | battery readout plus three icon buttons |
| `IconButton` | one round button used by `SessionControls` |
| *(clock)* | two `Text` elements; no wrapper earns its place |

### Icons

Nerd Font glyphs, matching what Omarchy's `LockView` already does — it renders
`text: "󰈷"` for the fingerprint hint at line 216. No `MaterialSymbol` port and
no new font dependency.

All eight were verified present in **JetBrainsMono Nerd Font**, which is what
`monospace` resolves to on this machine and therefore what `Style.font.family`
renders with:

| Glyph | Codepoint | Use |
|---|---|---|
| 󰌆 | U+F0306 | YubiKey / security key |
| 󰈷 | U+F0237 | fingerprint |
| 󰌾 | U+F033E | lock (neither method available) |
| 󰁹 | U+F0079 | battery |
| 󰂄 | U+F0084 | battery charging |
| 󰤄 | U+F0904 | suspend |
| 󰐥 | U+F0425 | power off |
| 󰜉 | U+F0709 | restart |

## State ownership

Follows the pattern Phase 1 established: `Service.qml` computes, `LockView.qml`
renders.

| State | Owner | Reason |
|---|---|---|
| `primaryMethod`, `u2fConfigured` | `Service.qml` | already there, unchanged |
| Battery percent / charging | `LockView` via `Quickshell.Services.UPower` | a singleton; needs no plumbing |
| Shutdown / reboot / suspend | `Service.qml` `Process` | the existing `Process` blocks live there |
| `passwordRevealed` | `LockView`, local | pure presentation |
| Animation properties | `LockView`, local | pure presentation |

Session commands: `omarchy system shutdown` and `omarchy system reboot` exist as
`omarchy-system-shutdown` / `omarchy-system-reboot`. There is **no**
`omarchy-system-suspend`, so suspend uses `systemctl suspend`.

## The hardware prompt

The glyph pulses only while a device is actually armed, so it reads as "waiting
on you" rather than as decoration.

| `primaryMethod` | Line 1 | Line 2 |
|---|---|---|
| `yubikey` | Touch your YubiKey | or scan your fingerprint |
| `fingerprint` | Scan your fingerprint | or plug in your YubiKey |
| `password` | *(island hidden)* | |

The third row is the one that matters. With no key and no enrolled finger there
is nothing to prompt for, so the hardware island is hidden entirely and the
password field starts revealed. A dead island prompting for hardware that does
not exist would be worse than no island.

Line 2 adapts: when `primaryMethod` is `yubikey` but no fingerprint is enrolled,
it reads "Waiting for a touch" rather than offering a method that is not there.

## Password reveal

`passwordRevealed` starts false. It becomes true when:

- any printable key is pressed, or
- Esc is pressed, or
- `primaryMethod` is `password` (nothing else to offer)

It returns to false when Esc is pressed with an already-empty field.

**The `TextInput` never leaves the tree and never loses focus.** While hidden it
is `opacity: 0` — never `visible: false`, because an invisible item stops
receiving key events and the first character of the password would be swallowed.
This is the single most failure-prone mechanic in the phase and the one to get
right first.

The hint pill ("Type or press Esc to use your password") is visible only while
the field is hidden.

## Entrance animation — stage 2

Lands as its own commit after the surface works.

- Wallpaper scales 1 → 1.1 with a blur ramp
- A neutral black dim fades to ~0.4, so islands keep contrast on any wallpaper
- Islands and clock fade in from `opacity: 0`, `scale: 0.9`

One wrinkle: Omarchy's `LockView` already runs an always-on `MultiEffect` blur,
so this animates a property that currently simply *is*. Ramp `blurMultiplier`
rather than toggling `blurEnabled`, which would flash.

## Verification

Everything visual is checkable **without locking the screen**. `LockView` is
instantiated twice — once in `WlSessionLockSurface`, once in a `PanelWindow`
namespaced `omarchy-lock-preview` — so:

```bash
omarchy-shell lock preview      # renders the real surface, dismissible
omarchy-shell lock hidePreview
```

States to check through the preview: key present, key absent, no key and no
finger (password mode), password revealed, password hidden, battery present,
battery absent.

A real session lock is needed only for the final confirmation, and only with a
TTY logged in on another VT.

**After every edit to a plugin file, run `omarchy restart shell`.** The plugin
is `keepLoaded: true`, so Quickshell logs `Local plugin changed, reloading` but
does not re-instantiate the service. Phase 1 lost a live lock to exactly this.
Never verify a change against state that existed before it.

## Dropped deliberately

| Thing | Why |
|---|---|
| ii's error-shake animation | Omarchy already surfaces `failureMessage` in the field |
| `PasswordChars` custom dot rendering | Omarchy's `echoMode: Password` is sufficient |
| Keyring unlock on unlock | Phase 1 proved Omarchy never touches the keyring |
| Left island (username, layout) | both contents are invariants on this machine |
| Fcitx systray | lived in the dropped island |

## Edge cases

- **No battery** (desktop): the battery readout hides rather than rendering a
  dead icon. `UPower.displayDevice` reports whether one exists.
- **Multiple monitors**: `WlSessionLockSurface` is created per screen, so the
  islands render on each. This matches ii.
- **Key unplugged while locked**: `primaryMethod` already tracks this live
  (Phase 1, verified). The prompt follows it, and the password field reveals
  itself if the method falls to `password`.

## Open questions

None. The parent spec's open questions 1 and 3 are resolved above; question 2
(keyring) was answered during Phase 1.
