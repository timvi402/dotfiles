# Lock screen Phase 2 — the island surface

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the lock's centered password field with two bottom-anchored islands — a hardware prompt and session controls — under a large clock, with the password field hidden until deliberately summoned.

**Architecture:** All presentation lives in `LockView.qml` as QML6 inline `component` declarations; `Service.qml` gains only the session-action processes. Nothing about authentication changes — Phase 1's PAM flows are untouched.

**Tech Stack:** QML / Quickshell (`Quickshell.Services.UPower`, `Quickshell.Io`), QtQuick + QtQuick.Effects, Nerd Font glyphs, Omarchy `Color`/`Style` singletons.

**Spec:** `docs/superpowers/specs/2026-08-18-lock-surface-phase2-design.md`

## Global Constraints

- Never edit `/usr/share/omarchy/`. It is package-owned and overwritten on update. Reading it is encouraged.
- All plugin edits go in `~/.config/omarchy/plugins/timmy-xlent.lock/`. **These are now stow symlinks into `~/dotfiles/omarchy/.config/omarchy/plugins/timmy-xlent.lock/`** — editing either path edits both. Commit from `~/dotfiles`; no `cp` step is needed any more.
- **After every edit to a plugin file, run `omarchy restart shell` and wait ~5s.** The plugin is `keepLoaded: true`, so Quickshell logs `Local plugin changed, reloading` but does NOT re-instantiate the service. Phase 1 lost a live lock to exactly this.
- **Never verify a change against state that existed before it.** Phase 1 had a verification step that passed while proving nothing because every field it checked predated the edit.
- **Never run `omarchy-shell lock lock` without a human present.** A human is at this keyboard. Use `omarchy-shell lock preview` for all visual work.
- Colours come from `Color.lock.*`, sizes from `Style.font.*`. Nothing hardcoded — the lock must keep following the active theme.
- Icons are Nerd Font glyphs, verified present in JetBrainsMono Nerd Font (what `monospace` resolves to here).

## Why there are no unit tests

No test harness exists for Quickshell plugins, and inventing one is out of scope. Verification is command-based. Phase 2 is almost entirely presentation, which makes it unusually well served by one command:

```bash
omarchy-shell lock preview      # renders the REAL LockView in a dismissible overlay
omarchy-shell lock hidePreview
```

`Service.qml` instantiates `LockView` twice — once in `WlSessionLockSurface`, once in a `PanelWindow` namespaced `omarchy-lock-preview`. **Both must receive every new property**, or preview and reality diverge and every later test lies. Treat "expected output" and "expected appearance" as the assertions.

## File structure

| File | Responsibility | Tasks |
|---|---|---|
| `Service.qml` | session-action processes; pass-through bindings on both LockView instantiations | 1, 4 |
| `LockView.qml` | the entire surface: pills, clock, prompt, controls, reveal logic, animation | 2-6 |

`LockView.qml` grows from 225 to roughly 500 lines. That is deliberate: no first-party Omarchy plugin ships a `.qml` file beyond its entry points, so sibling-component resolution is untested and a lock screen is the wrong place to discover it. Inline `component` declarations give real units in one file — the same approach ii's own `LockSurface.qml` takes.

## Reference: the geometry and glyphs

Copy these values verbatim; they are the spec's, taken from ii.

| Property | Value |
|---|---|
| Pill height | 56 |
| Pill radius | `height / 2` |
| Pill horizontal padding | 8 (so `implicitWidth` = content + 16) |
| Gap between pills | 10 |
| Distance from bottom | 20 |
| Clock font size / weight | 120 / 500 |
| Clock vertical offset | `-parent.height * 0.06` |
| Pulse | 1.0 ↔ 0.4, 900ms each direction, `Easing.InOutQuad` |

| Glyph | Meaning |
|---|---|
| `"󰌆"` | YubiKey / security key |
| `"󰈷"` | fingerprint |
| `"󰁹"` | battery |
| `"󰂄"` | battery charging |
| `"󰤄"` | suspend |
| `"󰐥"` | power off |
| `"󰜉"` | restart |

---

### Task 1: Session actions in Service.qml

Backend only — nothing visible changes. Task 4's buttons call these.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml`

**Interfaces:**
- Consumes: nothing.
- Produces, on the `Service.qml` root object:
  - `function doPowerOff()` — runs `omarchy-system-shutdown`
  - `function doReboot()` — runs `omarchy-system-reboot`
  - `function doSuspend()` — runs `systemctl suspend`

- [ ] **Step 1: Add the three processes**

After the existing `blankProcess` `Process` block (search for `id: blankProcess`), add:

```qml
  // Session actions offered on the lock surface. There is no
  // omarchy-system-suspend, so suspend goes through systemctl directly.
  Process {
    id: powerOffProcess
    command: ["bash", "-c", "omarchy-system-shutdown"]
  }

  Process {
    id: rebootProcess
    command: ["bash", "-c", "omarchy-system-reboot"]
  }

  Process {
    id: suspendProcess
    command: ["bash", "-c", "systemctl suspend"]
  }
```

- [ ] **Step 2: Add the three functions**

Beside `runWake()` (search for `function runWake`), add:

```qml
  function doPowerOff() {
    logEvent("session-action: poweroff")
    powerOffProcess.running = true
  }

  function doReboot() {
    logEvent("session-action: reboot")
    rebootProcess.running = true
  }

  function doSuspend() {
    logEvent("session-action: suspend")
    suspendProcess.running = true
  }
```

`logEvent` already exists and writes to the shell log, which is how Step 4 verifies the wiring without actually shutting the machine down.

- [ ] **Step 3: Restart the shell and confirm nothing regressed**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock status | jq '{passwordPam, fingerprint, u2fPam, primaryMethod}'
```

Expected: `{"passwordPam": true, "fingerprint": true, "u2fPam": true, "primaryMethod": "yubikey"}`

If `lock status` does not answer, the QML has a syntax error. Fix it immediately — never leave the shell broken.

- [ ] **Step 4: Verify the commands exist and are spelled right**

The functions cannot be called safely (two of them end the session), so verify the strings instead:

```bash
command -v omarchy-system-shutdown omarchy-system-reboot
systemctl --help >/dev/null && echo "systemctl ok"
grep -n "omarchy-system-shutdown\|omarchy-system-reboot\|systemctl suspend" \
  ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
```

Expected: both `omarchy-system-*` paths resolve under `/usr/share/omarchy/bin/`, `systemctl ok`, and the grep shows exactly three lines — one per Process.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
git commit -m "lock: add session actions for the surface to call

Power off and reboot go through omarchy-system-*, which close windows
first. There is no omarchy-system-suspend, so suspend uses systemctl.

Each logs through logEvent before firing, so the wiring is verifiable
from the shell log without actually ending the session."
```

---

### Task 2: The Pill component and the clock

The visual foundation. The old centered field stays untouched and on screen; this only adds a clock above it.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`

**Interfaces:**
- Consumes: nothing.
- Produces, inside `LockView.qml`:
  - `component Pill: Rectangle` — default-property container; children land in a centered `Row` with spacing 12
  - `property date now` — ticking clock source, updated every second

- [ ] **Step 1: Add the clock tick source**

In `LockView.qml`, after `property bool syncingPasswordText: false` (near line 20), add:

```qml
  // Clock source. A one-second tick is enough for HH:mm and keeps the date
  // line correct across midnight without a second timer.
  property date now: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }
```

- [ ] **Step 2: Add the Pill component**

At the very end of `LockView.qml`, immediately before the final closing `}`, add:

```qml
  // A Material-style pill. Children are laid out in a centered row; the pill
  // sizes itself to them. Geometry matches the ii lock surface this ports.
  component Pill: Rectangle {
    id: pill
    default property alias content: pillRow.data

    implicitHeight: 56
    implicitWidth: pillRow.implicitWidth + 16
    radius: height / 2
    color: Color.lock.background

    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowBlur: 0.6
      shadowOpacity: 0.35
      shadowVerticalOffset: 2
    }

    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 12
    }
  }
```

- [ ] **Step 3: Add the clock**

Inside the outer `Rectangle` (the one whose first child is `Image { id: wallpaper }`), after the `MouseArea` block and before `BorderSurface { id: inputField`, add:

```qml
    // Clock, centered above the islands.
    Column {
      id: clockColumn
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -parent.height * 0.06
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: 120
        font.weight: 500
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading)
      }
    }
```

- [ ] **Step 4: Restart and look at it**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock preview
```

Expected on screen: a large `HH:mm` clock with a `Monday, 18 August` style date line beneath it, above the existing password field. The field is still there and unchanged — this task does not touch it.

Dismiss with `omarchy-shell lock hidePreview`.

**Ask the human to confirm what they see.** You cannot read text off a screen; do not claim you can.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml
git commit -m "lock: add the clock and a Pill component

Pill is the shared island container -- 56px tall, fully rounded, sized to
its children, with a soft shadow. Inline component rather than a sibling
file: no first-party Omarchy plugin ships extra .qml, so sibling
resolution is untested and a lock screen is the wrong place to find out.

The clock ticks once a second, which is enough for HH:mm and keeps the
date line correct across midnight without a second timer."
```

---

### Task 3: The hardware prompt island

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`

**Interfaces:**
- Consumes: `Pill` (Task 2); `primaryMethod`, `fingerprintConfigured` (existing properties).
- Produces: `readonly property bool hardwareMode`; an item with `id: hardwareIsland`.

- [ ] **Step 1: Add the hardwareMode property**

After `readonly property bool errorState: ...` (near line 43), add:

```qml
  // True when there is hardware to wait for. When false there is nothing to
  // prompt for, so the island hides and the password field carries the surface.
  readonly property bool hardwareMode: root.primaryMethod !== "password"
```

- [ ] **Step 2: Add the island**

Inside the outer `Rectangle`, after the `clockColumn` block from Task 2, add:

```qml
    // Hardware prompt: says what the machine is waiting for.
    Pill {
      id: hardwareIsland
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 20
      visible: root.hardwareMode

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.primaryMethod === "yubikey" ? "󰌆" : "󰈷"
        color: Color.lock.borderActive
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.6)

        // Pulses only while a device is armed, so it reads as "waiting on you"
        // rather than as decoration.
        SequentialAnimation on opacity {
          running: root.hardwareMode
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.4; duration: 900; easing.type: Easing.InOutQuad }
          NumberAnimation { from: 0.4; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
          text: root.primaryMethod === "yubikey" ? "Touch your YubiKey" : "Scan your fingerprint"
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading)
        }

        Text {
          text: {
            if (root.primaryMethod === "yubikey")
              return root.fingerprintConfigured ? "or scan your fingerprint" : "Waiting for a touch"
            return root.u2fConfigured ? "or plug in your YubiKey" : "Waiting for a scan"
          }
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 0.8)
        }
      }
    }
```

The second line never offers a method that is not there — that is what the `fingerprintConfigured` and `u2fConfigured` checks are for.

- [ ] **Step 3: Move the password field out of the way**

The field currently sits at `anchors.centerIn: parent` and would collide with the clock. Change its anchors so it sits just above the island. Find `BorderSurface { id: inputField` and replace its `anchors.centerIn: parent` line with:

```qml
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.hardwareMode ? 86 : 20
```

- [ ] **Step 4: Restart and check both states**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock preview
```

Expected with the YubiKey plugged in: a pill reading **󰌆 Touch your YubiKey / or scan your fingerprint**, bottom-center, its glyph pulsing.

Then, with the preview still open, ask the human to unplug the key. Expected: it becomes **󰈷 Scan your fingerprint / or plug in your YubiKey**.

```bash
omarchy-shell lock hidePreview
```

**Ask the human to confirm both states.** You cannot see the screen.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml
git commit -m "lock: add the hardware prompt island

Says what the machine is waiting for, with the glyph pulsing while a
device is armed. The second line never offers a method that is not
enrolled -- it degrades to 'Waiting for a touch' rather than pointing at
a fingerprint reader with nothing registered.

The island hides entirely when primaryMethod is password: with no key and
no finger there is nothing to prompt for, and an island asking for
hardware that does not exist is worse than no island."
```

---

### Task 4: The session island

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml`

**Interfaces:**
- Consumes: `Pill` (Task 2); `hardwareIsland` (Task 3); `doPowerOff()`, `doReboot()`, `doSuspend()` (Task 1).
- Produces: `LockView` signals `powerOffRequested()`, `rebootRequested()`, `suspendRequested()`; `component IconButton: Rectangle`.

- [ ] **Step 1: Add the signals**

In `LockView.qml`, after `signal wakeRequested()` (near line 51), add:

```qml
  signal powerOffRequested()
  signal rebootRequested()
  signal suspendRequested()
```

- [ ] **Step 2: Import UPower**

At the top of `LockView.qml`, after `import QtQuick.Effects`, add:

```qml
import Quickshell.Services.UPower
```

- [ ] **Step 3: Add the IconButton component**

Immediately after the `component Pill: Rectangle { ... }` block, add:

```qml
  // One round action button for the session island.
  component IconButton: Rectangle {
    id: button
    property string glyph: ""
    signal activated()

    implicitWidth: 40
    implicitHeight: 40
    radius: width / 2
    color: mouse.containsMouse ? Color.lock.selection : "transparent"

    Text {
      anchors.centerIn: parent
      text: button.glyph
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.heading * 1.1)
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.activated()
    }
  }
```

- [ ] **Step 4: Add the island**

After the `hardwareIsland` block, add:

```qml
    // Session controls. Battery hides itself on a machine without one.
    Pill {
      id: sessionIsland
      anchors.left: hardwareIsland.right
      anchors.leftMargin: 10
      anchors.verticalCenter: hardwareIsland.verticalCenter

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        // Gated on the API omarchy's own battery service uses. `isLaptopBattery`
        // exists in some Quickshell builds but could not be confirmed on this
        // machine, so presence is inferred from a non-zero percentage instead.
        visible: UPower.displayDevice !== null && UPower.displayDevice.percentage > 0

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: UPower.onBattery ? "󰁹" : "󰂄"
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.1)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: UPower.displayDevice ? Math.round(Number(UPower.displayDevice.percentage || 0) * 100) : ""
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading)
        }
      }

      IconButton { glyph: "󰤄"; onActivated: root.suspendRequested() }
      IconButton { glyph: "󰐥"; onActivated: root.powerOffRequested() }
      IconButton { glyph: "󰜉"; onActivated: root.rebootRequested() }
    }
```

- [ ] **Step 5: Wire both LockView instantiations**

In `Service.qml` there are two `LockView` blocks — one inside `WlSessionLockSurface`, one inside `PanelWindow`. **Both** need the handlers. In each, after the existing `onWakeRequested:` line, add:

```qml
        onPowerOffRequested: root.doPowerOff()
        onRebootRequested: root.doReboot()
        onSuspendRequested: root.doSuspend()
```

The preview instantiation has no `onWakeRequested` line — add the three handlers after its `passwordText: ""` line instead.

Verify both landed:

```bash
grep -c "onPowerOffRequested" ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
```

Expected: `2`. If it is 1, the preview will render buttons that do nothing.

- [ ] **Step 6: Restart and check appearance**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock preview
```

Expected: a second pill to the right of the hardware prompt, showing a battery percentage (this machine is a laptop) and three round buttons — moon, power, restart — that highlight on hover.

**Do NOT click the power or restart buttons** — they end the session. Clicking suspend is safe if the human wants to test it.

```bash
omarchy-shell lock hidePreview
```

**Ask the human to confirm.**

- [ ] **Step 7: Verify the wiring without ending the session**

The buttons cannot be clicked safely, so confirm the signal path by checking that the handlers exist on both instantiations and that `logEvent` will fire:

```bash
grep -n "onPowerOffRequested\|onRebootRequested\|onSuspendRequested" \
  ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
grep -n "session-action" ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
```

Expected: six handler lines (three per instantiation) and three `logEvent("session-action: ...")` lines from Task 1.

If the human is willing, clicking suspend in the preview is a safe end-to-end test — the machine suspends and resumes, and `journalctl --user | grep session-action` afterwards shows `session-action: suspend`.

- [ ] **Step 8: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml \
        omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
git commit -m "lock: add the session island

Battery readout plus suspend, power off and restart. The battery row
hides itself when UPower reports no laptop battery, so this does not
render a dead icon on a desktop.

Buttons act immediately, carried from the ii config
(requirePasswordToPower: false) -- one click from the locked screen fires
the action, which is roughly what the physical power button allows.

Wired on BOTH LockView instantiations. Missing the preview one would
leave buttons that render but do nothing there, and every later visual
test goes through preview."
```

---

### Task 5: Password reveal

The subtlest task. The field stops being the surface and becomes something you summon.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`

**Interfaces:**
- Consumes: `hardwareMode` (Task 3); `hardwareIsland`, `sessionIsland` (Tasks 3-4).
- Produces: `property bool passwordRevealed`; `readonly property bool passwordVisible`.

- [ ] **Step 1: Add the reveal state**

After the `hardwareMode` property from Task 3, add:

```qml
  // The password box is summoned, not offered. passwordRevealed is the user's
  // deliberate action; passwordVisible folds in the case where there is no
  // hardware at all and the password is the only way in.
  property bool passwordRevealed: false
  readonly property bool passwordVisible: !root.hardwareMode || root.passwordRevealed
```

- [ ] **Step 2: Hide the field until summoned**

On `BorderSurface { id: inputField`, add these two lines beside its existing anchors:

```qml
      opacity: root.passwordVisible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 150 } }
```

**Do NOT add `visible: false`.** An invisible item stops receiving key events, and the first character of the password would be swallowed. The field stays in the tree, focused, merely transparent. This is the single most failure-prone mechanic in the phase.

- [ ] **Step 3: Reveal on the first keystroke**

In the `TextInput`'s `onTextChanged` handler, add the reveal beside the existing wake:

```qml
        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.passwordRevealed = true
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }
```

- [ ] **Step 4: Make Esc toggle**

Replace the `TextInput`'s existing `Keys.onPressed` handler with:

```qml
        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            // Esc on an empty field toggles the box away again; with text in it,
            // Esc clears first. Two presses always get you back to the prompt.
            if (event.key === Qt.Key_Escape && passwordInput.text.length === 0) {
              root.passwordRevealed = !root.passwordRevealed
            } else {
              root.passwordTextEdited("")
            }
            event.accepted = true
          }
        }
```

- [ ] **Step 5: Hide the islands when the field is up**

The prompt and the field should not both claim the surface. On `hardwareIsland`, change its `visible` line to:

```qml
      visible: root.hardwareMode && !root.passwordRevealed
```

And on `sessionIsland`, anchor it to the screen rather than to a hidden sibling, so it survives the prompt disappearing. Replace its three anchor lines with:

```qml
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: hardwareIsland.visible ? (hardwareIsland.width / 2 + 10 + width / 2) : 0
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 20
```

This keeps the pair centered as a group when both are up, and centers the session island alone when the prompt is gone.

- [ ] **Step 6: Reseat the password field**

Task 3 put the field at `bottomMargin: root.hardwareMode ? 86 : 20`, clearing the island beneath it. Now that the islands hide whenever the field is up, that gap is empty space. On `BorderSurface { id: inputField`, change the margin to:

```qml
      anchors.bottomMargin: 20
```

- [ ] **Step 7: Add the hint pill**

After the `sessionIsland` block, add:

```qml
    // Quiet reminder that a password is still reachable, for the day the key is
    // lost and the reader will not read.
    Pill {
      id: fallbackHint
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: hardwareIsland.top
      anchors.bottomMargin: 12
      visible: root.hardwareMode && !root.passwordRevealed
      implicitHeight: 36
      opacity: 0.75

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Type or press Esc to use your password"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 0.8)
      }
    }
```

- [ ] **Step 8: Simplify the placeholder**

The method-aware wording now lives in the island, so the field only ever needs to say what it is. Replace the `placeholderText` block (near line 22) with:

```qml
  readonly property string placeholderText: "Enter Password"
```

This also retires the Phase 1 deferred item where "Place your finger on the reader" elided in the 381px field — the long strings live in the two-line island now, which has room.

- [ ] **Step 9: Restart and check every state**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock preview
```

Ask the human to confirm, in the preview:

1. With the key in: the hardware prompt and hint pill are visible, **no password field**.
2. Pressing Esc: the field appears, prompt and hint disappear.
3. Pressing Esc again on the empty field: back to the prompt.
4. Typing a character: the field appears **with that character in it** — this is the mechanic that matters; a swallowed first keystroke means Step 2 was done wrong.

```bash
omarchy-shell lock hidePreview
```

Note: `inputEnabled` is false in the preview instantiation, so typing may not work there. If so, say that plainly and defer items 2-4 to the real lock in Task 6.

- [ ] **Step 10: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml
git commit -m "lock: summon the password field instead of offering it

The box is hidden behind a deliberate action -- type anything, or press
Esc -- so the hardware prompt carries the surface and the key is the
obvious path. Esc on an empty field puts it away again.

The field never leaves the tree and never loses focus; hidden means
opacity 0, never visible: false. An invisible item stops receiving keys,
which would swallow the first character of the password.

When primaryMethod is password there is no hardware to wait for, so the
field starts revealed and the islands stay down.

Retires the Phase 1 deferred item about the fingerprint string eliding:
the long wording now lives in the island's two-line label."
```

---

### Task 6: Entrance animation

Lands last so a misbehaving animation can be reverted without touching a working surface.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`

**Interfaces:**
- Consumes: everything above.
- Produces: `property real entered` — 0 before the surface settles, 1 after.

- [ ] **Step 1: Add the entrance driver**

After the `passwordVisible` property from Task 5, add:

```qml
  // Drives the entrance. Starts at 0 and animates to 1 once the surface is up;
  // everything that animates in reads from this rather than keeping its own state.
  property real entered: 0

  Behavior on entered {
    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
  }

  Component.onCompleted: Qt.callLater(function () { root.entered = 1 })
```

- [ ] **Step 2: Ramp the wallpaper blur and zoom**

Omarchy's `MultiEffect` blur is always on, so ramp its multiplier rather than toggling `blurEnabled` — toggling flashes. On the `MultiEffect` block, replace `blurMultiplier: 1.25` with:

```qml
      blurMultiplier: 1.25 * root.entered
```

And on `Image { id: wallpaper }`, add:

```qml
      scale: 1 + 0.1 * root.entered
```

- [ ] **Step 3: Add the dim**

Immediately after the `MultiEffect` block, add:

```qml
    // Neutral dim so the clock and islands keep contrast on any wallpaper,
    // without tinting it toward the theme colour.
    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: 0.4 * root.entered
    }
```

- [ ] **Step 4: Fade and scale the content**

On each of `clockColumn`, `hardwareIsland`, `sessionIsland` and `fallbackHint`, add these two lines. For `fallbackHint`, which already sets `opacity: 0.75`, use `opacity: 0.75 * root.entered` instead of the line below:

```qml
      opacity: root.entered
      scale: 0.9 + 0.1 * root.entered
```

- [ ] **Step 5: Restart and watch it**

```bash
omarchy restart shell && sleep 6
omarchy-shell lock preview
```

Expected: the wallpaper blurs and zooms in slightly while the dim deepens; the clock and islands fade up and grow from slightly small. All of it over roughly 400ms.

```bash
omarchy-shell lock hidePreview
```

**Ask the human to confirm it looks right and does not flash.** A flash on entry means `blurEnabled` is being toggled somewhere rather than the multiplier ramped.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml
git commit -m "lock: animate the surface in

Wallpaper zooms and its blur ramps while a neutral dim deepens; the clock
and islands fade up from slightly small. One 'entered' property drives all
of it, so nothing keeps its own animation state.

The blur multiplier is ramped rather than blurEnabled toggled -- Omarchy's
MultiEffect blur is always on, and toggling it flashes."
```

---

### Task 7: Close out

**Files:**
- Modify: `docs/superpowers/specs/2026-08-18-lock-surface-phase2-design.md`

- [ ] **Step 1: The real lock, end to end**

Everything so far has gone through `preview`. Confirm the real surface, with a human present and a TTY logged in on another VT (`Ctrl+Alt+F2`, log in, `Ctrl+Alt+F1` to return):

```bash
loginctl list-sessions          # confirm a tty session exists before locking
```

Then ask the human to press **SUPER+L** and confirm:

1. The clock and both islands render, animated in.
2. The prompt reads "Touch your YubiKey".
3. Touching the key unlocks.
4. Locking again and typing reveals the field with the first character present, and the password unlocks.

- [ ] **Step 2: Confirm nothing regressed in authentication**

```bash
journalctl --since "-5 min" | grep "Starting pam session" | sed 's/.*with config //;s/ in dir.*//' | sort | uniq -c
```

Expected: `omarchy-lock-u2f` and `omarchy-lock-password` both appear, and no `authentication failure` lines beyond any deliberate mistyping.

- [ ] **Step 3: Mark the spec implemented and commit**

Add a status line under the Phase 2 spec's Goal section recording the date and the commit range, mirroring how the Phase 1 spec was closed out.

```bash
cd ~/dotfiles
git add docs/superpowers/specs/2026-08-18-lock-surface-phase2-design.md
git commit -m "docs: mark lock Phase 2 implemented"
```

---

## Not in this plan

- **Restoring the left island.** Dropped by design; both its contents are invariants on this machine. If a second keyboard layout ever appears, it becomes worth building.
- **The unthrottled presence poll** while locked with the key absent (~2,400 `fido2-token` spawns/hour). A real improvement, carried over from Phase 1's final review, but it is behaviour rather than appearance and belongs in its own change.
- **Multi-monitor tuning.** `WlSessionLockSurface` is per-screen so the islands render on each, matching ii. If that turns out to be wrong on this setup, it is a follow-up.
