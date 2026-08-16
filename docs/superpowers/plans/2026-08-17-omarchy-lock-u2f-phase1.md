# Omarchy lock — YubiKey (u2f) authentication, Phase 1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unlock the session by touching a YubiKey, on Omarchy 4.0's native Quickshell lock, with fingerprint and password still working as they do today.

**Architecture:** Clone the first-party `omarchy.lock` plugin into a user-owned copy, add a third PAM flow (`omarchy-lock-u2f`) beside the existing password and fingerprint flows, and drive it from a `fido2-token -L` presence poll. The lock surface stays as Omarchy ships it apart from its prompt text; the three-island port is Phase 2 and is not in this plan.

**Tech Stack:** QML / Quickshell (`Quickshell.Services.Pam`, `Quickshell.Io`), PAM (`pam_u2f`), bash, Hyprland, Arch.

**Spec:** `docs/superpowers/specs/2026-08-17-omarchy-lock-yubikey-port-design.md`

## Global Constraints

- Never edit `/usr/share/omarchy/`. It is owned by the `omarchy` package and is overwritten on update. Reading it is fine and encouraged.
- All plugin edits go in `~/.config/omarchy/plugins/timmy-xlent.lock/` — created by `omarchy plugin clone`, never by hand.
- `/etc/pam.d/` needs root. Use `sudo` from an interactive terminal, never `pkexec`, so the password prompt has a terminal to land in.
- A broken lock screen locks the session out or leaves the machine open. **No task may lock the screen until its verification has passed by another means.** Every task below is verifiable without locking, except Task 4, which locks only after Task 1 and Task 3 have passed and only with a TTY escape hatch open.
- Saving any file under `~/.config/omarchy/plugins/` hot-reloads the shell. There is no build step and no restart.
- Target the exact strings the spec fixes: PAM service name `omarchy-lock-u2f`, authfile `/etc/fido2/fido2`, plugin id `timmy-xlent.lock`.
- This machine is Omarchy `4.0.0-1`. Record that baseline (Task 6) — a cloned plugin stops receiving upstream updates.

## Why there are no unit tests here

There is no test harness for Quickshell plugins on this system, and inventing one is out of scope. Verification is command-based instead, and the spec designed three observation points that make each step checkable without a lock:

| Command | Answers |
|---|---|
| `pamtester omarchy-lock-u2f "$USER" authenticate` | does the PAM stack authenticate the key? |
| `omarchy-shell lock status \| jq` | does the shell see the key, and what will it try first? |
| `omarchy-shell lock preview` | what does the surface look like? |

Each task states the command, the expected output, and what to do when it fails. Treat "expected output" as the assertion.

## File structure

| File | Responsibility |
|---|---|
| `/etc/pam.d/omarchy-lock-u2f` | the u2f auth stack, root-owned. Task 1. |
| `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml` | detection, PAM lifecycle, IPC status. Tasks 3, 4. |
| `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml` | prompt text only in this phase. Task 5. |
| `~/.config/omarchy/plugins/timmy-xlent.lock/manifest.json` | written by the clone script. **Never edited by hand.** |
| `~/dotfiles/omarchy/.config/omarchy/plugins/timmy-xlent.lock/` | the tracked copy. Task 6. |

---

### Task 1: The PAM service, verified in isolation

Nothing in the shell changes here. The point is to know the stack authenticates before any QML depends on it.

**Files:**
- Create: `/etc/pam.d/omarchy-lock-u2f`

**Interfaces:**
- Consumes: nothing.
- Produces: a PAM service named `omarchy-lock-u2f`, referenced by `PamContext.config` in Task 4 and by a `FileView` path in Task 3.

- [ ] **Step 1: Confirm the enrollment and the key are both present**

```bash
ls -l /etc/fido2/fido2 && fido2-token -L
```

Expected: the authfile exists and is non-empty, and `fido2-token -L` prints a line containing `/dev/` (e.g. `/dev/hidraw1: vendor=0x1050, product=0x0407 (Yubico YubiKey OTP+FIDO+CCID)`).

If `fido2-token -L` prints nothing, the key is not plugged in. Plug it in — everything below needs it.

- [ ] **Step 2: Install pamtester**

```bash
omarchy pkg aur add pamtester
```

It is AUR-only (`aur/pamtester 0.1.2-4`); it is not in the Arch repos.

- [ ] **Step 3: Write the PAM service**

```bash
sudo tee /etc/pam.d/omarchy-lock-u2f >/dev/null <<'EOF'
#%PAM-1.0
auth       required   pam_u2f.so cue authfile=/etc/fido2/fido2
account    include    system-local-login
EOF
```

Shaped after `/etc/pam.d/omarchy-lock-fingerprint`, which is the closest existing analogue: a single-mechanism stack whose success is the unlock. `required` rather than the `sufficient` used in `/etc/pam.d/hyprlock` — hyprlock stacks u2f ahead of `include login` and needs to short-circuit, whereas here the `PamContext` completing *is* the unlock.

- [ ] **Step 4: Verify it authenticates with a touch**

```bash
pamtester omarchy-lock-u2f "$USER" authenticate
```

Expected: the key blinks, and after you touch it: `pamtester: successfully authenticated`.

If it hangs with no blink, the `authfile` path is wrong or the key is not enrolled in it. If it reports `Authentication service cannot retrieve authentication info`, the `authfile` is unreadable by you — check `ls -l /etc/fido2/fido2`.

- [ ] **Step 5: Verify it fails cleanly without a touch**

```bash
pamtester omarchy-lock-u2f "$USER" authenticate
```

Expected: do **not** touch the key. Within ~15s: `pamtester: Authentication failure`. A clean failure matters as much as the success — Task 4 retries on failure, and a stack that hangs instead of failing would wedge the retry loop.

- [ ] **Step 6: Verify the key's absence fails rather than hangs**

Unplug the key, then:

```bash
pamtester omarchy-lock-u2f "$USER" authenticate
```

Expected: prompt failure, `pamtester: Authentication failure`. Plug the key back in afterwards.

- [ ] **Step 7: Commit the PAM file's content to the repo as a record**

The live file is root-owned outside `$HOME`, so stow cannot manage it. Track a copy so a rebuild has it:

```bash
mkdir -p ~/dotfiles/etc/pam.d
sudo cat /etc/pam.d/omarchy-lock-u2f > ~/dotfiles/etc/pam.d/omarchy-lock-u2f
cd ~/dotfiles
git add etc/pam.d/omarchy-lock-u2f
git commit -m "pam: add omarchy-lock-u2f stack for YubiKey unlock

Verified with pamtester: authenticates on touch, fails cleanly on both
no-touch and no-key. Not stow-managed -- the live file is root-owned in
/etc, this is a record for rebuilds."
```

---

### Task 2: Clone the lock plugin

**Files:**
- Create: `~/.config/omarchy/plugins/timmy-xlent.lock/` (by script — `manifest.json`, `Service.qml`, `LockView.qml`)

**Interfaces:**
- Consumes: nothing.
- Produces: the plugin directory that Tasks 3-5 edit, and plugin id `timmy-xlent.lock`.

- [ ] **Step 1: Record the pre-clone state**

```bash
omarchy version
omarchy-shell lock status | jq
```

Expected: `4.0.0-1`, and status showing `"passwordPam":true` and `"fingerprint":true`. Write both down — Step 4 compares against them.

- [ ] **Step 2: Clone**

```bash
omarchy plugin clone omarchy.lock
```

Expected: `Cloned omarchy.lock to /home/timmy-xlent/.config/omarchy/plugins/timmy-xlent.lock and switched to timmy-xlent.lock`, plus a desktop notification.

- [ ] **Step 3: Verify the clone replaced the built-in rather than joining it**

```bash
ls ~/.config/omarchy/plugins/timmy-xlent.lock/
jq '{id, clonedFrom: .omarchy.clonedFrom, kinds}' ~/.config/omarchy/plugins/timmy-xlent.lock/manifest.json
jq '.disabledPlugins' ~/.config/omarchy/shell.json
```

Expected: the directory holds `manifest.json`, `Service.qml` **and** `LockView.qml` (the clone script copies the whole directory because the plugin's manifest is named `manifest.json`); the manifest reports `id: "timmy-xlent.lock"`, `clonedFrom: "omarchy.lock"`, `kinds: ["service"]`; and `disabledPlugins` now contains `"omarchy.lock"`.

That last one is the important assertion. `service` is a non-widget kind, so `PluginRegistry.qml:523-524` disables the source on enable. If `omarchy.lock` is **not** in `disabledPlugins`, stop — two lock services would be running, and locking is unsafe until that is resolved.

- [ ] **Step 4: Verify the lock still works through the clone**

```bash
omarchy-shell lock status | jq
```

Expected: identical to Step 1 — `"passwordPam":true`, `"fingerprint":true`. IPC still routes because `clonedFrom` maps the built-in id to the clone (`PluginRegistry.qml:153`), so `omarchy-system-lock` needs no change.

- [ ] **Step 5: Verify the surface still renders**

```bash
omarchy-shell lock preview
```

Expected: the lock surface appears as an overlay. Click to dismiss (or `omarchy-shell lock hidePreview`). This is a pristine copy, so it should look exactly as before.

- [ ] **Step 6: Commit the untouched clone as a baseline**

Committing before any edit makes every later diff readable, and preserves the 4.0.0-1 upstream text the Global Constraints call for.

```bash
mkdir -p ~/dotfiles/omarchy/.config/omarchy/plugins
cp -a ~/.config/omarchy/plugins/timmy-xlent.lock ~/dotfiles/omarchy/.config/omarchy/plugins/
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock
git commit -m "omarchy: clone omarchy.lock as timmy-xlent.lock (4.0.0-1 baseline)

Untouched copy of the first-party plugin, committed before any edit so
later diffs read against upstream. A cloned plugin stops receiving
updates to omarchy.lock, so this records which version it forked from."
```

---

### Task 3: YubiKey detection, without authentication

Adds presence detection and exposes it over IPC. No PAM context yet, so the lock's behavior is unchanged — which is what makes this verifiable without locking.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml`

**Interfaces:**
- Consumes: `omarchy-lock-u2f` from Task 1.
- Produces, on the `Service.qml` root object:
  - `property bool u2fPamConfigured` — `/etc/pam.d/omarchy-lock-u2f` exists
  - `property bool yubikeyPresent` — `fido2-token -L` sees a device
  - `readonly property string primaryMethod` — one of `"yubikey"`, `"fingerprint"`, `"password"`
  - `function refreshYubikeyStatus()`
  - IPC `status()` gains `yubikey`, `u2fPam`, `primaryMethod`

- [ ] **Step 1: Add the three properties**

In `Service.qml`, after `property bool fingerprintConfigured: false` (near line 24), add:

```qml
  property bool u2fPamConfigured: false
  property bool yubikeyPresent: false
  property bool u2fAuthenticating: false
```

`u2fAuthenticating` is declared here rather than in Task 4 so that `authenticating` and `resetAuthenticationState` only get touched once.

- [ ] **Step 2: Add `primaryMethod` and fold u2f into `authenticating`**

Replace the `authenticating` line (near line 38):

```qml
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating
```

with:

```qml
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating || u2fAuthenticating

  // What the surface should ask for first. Fingerprint outranks password, and a
  // present key outranks both; a configured-but-absent key falls through so the
  // prompt can say "insert" rather than "touch".
  readonly property string primaryMethod: {
    if (u2fPamConfigured && yubikeyPresent) return "yubikey"
    if (fingerprintConfigured) return "fingerprint"
    return "password"
  }
```

Folding `u2fAuthenticating` into `authenticating` is safe: the display-blanking timer gates on `authenticatingPassword` specifically (see the comment at `idleBlankTimer.onTriggered`), precisely so a long-armed non-password PAM does not hold the display up.

- [ ] **Step 3: Add the refresh function**

Beside `refreshFingerprintStatus()` (near line 106):

```qml
  function refreshYubikeyStatus() {
    if (!yubikeyCheckProc.running) yubikeyCheckProc.running = true
  }
```

- [ ] **Step 4: Add the detection process**

After the `fingerprintCheckProc` `Process` block (near line 387):

```qml
  Process {
    id: yubikeyCheckProc
    command: ["bash", "-c", "fido2-token -L 2>/dev/null | grep -q /dev/ && echo yes || echo no"]
    stdout: StdioCollector { id: yubikeyCheckStdout; waitForEnd: true }
    onExited: {
      var present = String(yubikeyCheckStdout.text || "").trim() === "yes"
      if (present !== root.yubikeyPresent) {
        root.yubikeyPresent = present
        root.logEvent("yubikey=" + present)
      }
    }
  }
```

Task 4 extends `onExited` to start authentication. It is deliberately inert here.

- [ ] **Step 5: Add the presence poll**

After the `Process` block from Step 4:

```qml
  Timer {
    id: yubikeyPollTimer
    interval: 1500
    repeat: true
    triggeredOnStart: true
    // Preview counts as well as a real lock: the preview surface renders the
    // same prompt, so it needs the same live presence state behind it.
    // Never probe while pam_u2f holds the token -- an active attempt already
    // proves the key is there, and a concurrent fido2-token leaves pam_u2f
    // sitting on a busy device.
    running: (root.locked || root.previewVisible) && !u2fPam.active
    onTriggered: root.refreshYubikeyStatus()
  }
```

`u2fPam` does not exist until Task 4. Until then the `running` expression cannot resolve, so **for this task only**, use:

```qml
    running: root.locked || root.previewVisible
```

and restore the `&& !u2fPam.active` guard in Task 4 Step 5. Leaving it out permanently is not an option — it is the failure ii documented.

Including `previewVisible` is what makes Steps 9 and 10 checkable at all: outside a lock or a preview the timer is stopped, so presence would never refresh and the status would report whatever the single startup poll happened to see.

- [ ] **Step 6: Detect the PAM file**

After the existing `FileView` for `omarchy-lock-password` (near line 491):

```qml
  FileView {
    path: "/etc/pam.d/omarchy-lock-u2f"
    watchChanges: true
    printErrors: false
    onLoaded: root.u2fPamConfigured = true
    onLoadFailed: root.u2fPamConfigured = false
    onFileChanged: reload()
  }
```

- [ ] **Step 7: Poll once at startup**

In `Component.onCompleted` (near line 504), add `refreshYubikeyStatus()`:

```qml
  Component.onCompleted: {
    refreshBackground()
    refreshFingerprintStatus()
    refreshYubikeyStatus()
    checkStrandedLock()
  }
```

- [ ] **Step 8: Expose it over IPC**

In the `status()` function (near line 523), add three fields to the returned object, after `fingerprint: root.fingerprintConfigured`:

```qml
        fingerprint: root.fingerprintConfigured,
        u2fPam: root.u2fPamConfigured,
        yubikey: root.yubikeyPresent,
        primaryMethod: root.primaryMethod,
```

- [ ] **Step 9: Verify detection with the key in**

Saving the file hot-reloads the shell. The poll only runs while locked or previewing, so open a preview to arm it. With the YubiKey plugged in:

```bash
omarchy-shell lock preview
sleep 2
omarchy-shell lock status | jq '{u2fPam, yubikey, primaryMethod, fingerprint}'
omarchy-shell lock hidePreview
```

Expected:

```json
{ "u2fPam": true, "yubikey": true, "primaryMethod": "yubikey", "fingerprint": true }
```

If `u2fPam` is false, Task 1 did not land. If `yubikey` is false, run the Step 4 command by hand to see what `fido2-token` prints — and confirm you added `previewVisible` to the timer's `running` condition, because without it nothing is polling.

- [ ] **Step 10: Verify detection with the key out**

Unplug the key, then:

```bash
omarchy-shell lock preview
sleep 2
omarchy-shell lock status | jq '{yubikey, primaryMethod}'
omarchy-shell lock hidePreview
```

Expected: `{"yubikey": false, "primaryMethod": "fingerprint"}` — the fallback resolving, which is the whole point of `primaryMethod`. Plug the key back in, repeat, and confirm it returns to `"yubikey"`.

- [ ] **Step 11: Commit**

```bash
cp -a ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml \
      ~/dotfiles/omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
git commit -m "lock: detect YubiKey presence and expose primaryMethod

Adds a fido2-token -L poll and the omarchy-lock-u2f PAM file check, and
reports both over the lock status IPC. No authentication yet -- this is
observable via 'omarchy-shell lock status' without locking the screen."
```

---

### Task 4: YubiKey authentication

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml`

**Interfaces:**
- Consumes: `u2fPamConfigured`, `yubikeyPresent`, `u2fAuthenticating` (Task 3); `omarchy-lock-u2f` (Task 1).
- Produces: `function startU2f()`, `function handleU2fFinished(result)`, and a `PamContext` with `id: u2fPam` that Task 3's poll guard references.

- [ ] **Step 1: Add the two lifecycle functions**

After `handleFingerprintFinished` (near line 228):

```qml
  function startU2f() {
    if (!lockRequested || !sessionLock.secure) return
    if (!u2fPamConfigured || !yubikeyPresent) return
    if (u2fPam.active || u2fAuthenticating) return

    u2fAuthenticating = true
    if (!u2fPam.start()) {
      u2fAuthenticating = false
    }
  }

  function handleU2fFinished(result) {
    u2fAuthenticating = false

    if (!lockRequested) return
    if (result === PamResult.Success) {
      finishUnlock()
    } else if (yubikeyPresent) {
      u2fRetryTimer.restart()
    }
  }
```

This mirrors `startFingerprint` / `handleFingerprintFinished` exactly, with `yubikeyPresent` where the fingerprint pair uses `fingerprintConfigured`.

These functions reference `u2fPam` and `u2fRetryTimer`, which Step 2 creates. Saving the file between Step 1 and Step 2 leaves it referencing objects that do not exist yet, and the shell hot-reloads on every save — so expect an error in the shell log until Step 2 lands, and do not go near a lock in between. Doing both steps before saving avoids it entirely.

- [ ] **Step 2: Add the PAM context**

After the `fingerprintPam` `PamContext` (near line 354):

```qml
  PamContext {
    id: u2fPam
    config: "omarchy-lock-u2f"
    user: root.userName

    onCompleted: function(result) {
      root.handleU2fFinished(result)
    }

    onError: function(error) {
      root.u2fAuthenticating = false
      if (root.lockRequested && root.yubikeyPresent) u2fRetryTimer.restart()
    }
  }

  Timer {
    id: u2fRetryTimer
    interval: 250
    repeat: false
    onTriggered: root.startU2f()
  }
```

- [ ] **Step 3: Arm it when the session becomes secure**

In `WlSessionLock.onSecureStateChanged` (near line 241), add `startU2f()` beside the existing fingerprint call:

```qml
      if (secure) {
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
        root.startFingerprint()
        root.startU2f()
      }
```

- [ ] **Step 4: Tear it down with everything else**

In `resetAuthenticationState()` (near line 116), add three lines:

```qml
  function resetAuthenticationState() {
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    failedAttempts = 0
    authenticatingPassword = false
    fingerprintAuthenticating = false
    u2fAuthenticating = false
    fingerprintRetryTimer.stop()
    u2fRetryTimer.stop()
    if (passwordPam.active) passwordPam.abort()
    if (fingerprintPam.active) fingerprintPam.abort()
    if (u2fPam.active) u2fPam.abort()
  }
```

- [ ] **Step 5: Restore the poll guard and start auth on detection**

`u2fPam` now exists, so restore the guard deferred in Task 3 Step 5:

```qml
    running: (root.locked || root.previewVisible) && !u2fPam.active
```

And extend `yubikeyCheckProc.onExited` so plugging the key in mid-lock arms it, and unplugging aborts:

```qml
    onExited: {
      var present = String(yubikeyCheckStdout.text || "").trim() === "yes"
      if (present !== root.yubikeyPresent) {
        root.yubikeyPresent = present
        root.logEvent("yubikey=" + present)
      }
      if (root.lockRequested && present) root.startU2f()
      else if (!present && u2fPam.active) u2fPam.abort()
    }
```

- [ ] **Step 6: Re-verify the no-lock observables still hold**

```bash
omarchy-shell lock status | jq '{u2fPam, yubikey, primaryMethod}'
```

Expected: unchanged from Task 3 Step 9 — `{"u2fPam": true, "yubikey": true, "primaryMethod": "yubikey"}`. A QML syntax error would show as the shell failing to reload; check `omarchy-shell lock status` still answers at all before going near a lock.

- [ ] **Step 7: Open the escape hatch**

Before the first live lock, press **Ctrl+Alt+F2** and log in on the TTY. Leave that session logged in. Come back with **Ctrl+Alt+F1**.

From that TTY you can recover with `pkill -f 'quickshell.*omarchy'` or `loginctl unlock-session`. Do not skip this step. The password and fingerprint paths are untouched, so this is belt-and-braces — but a wedged lock screen is not the moment to discover the TTY needs a password you have to type blind.

- [ ] **Step 8: Lock, and unlock with the YubiKey**

```bash
omarchy-shell lock lock
```

Expected: the lock appears, the key blinks, and touching it unlocks the session without typing anything.

If it locks but the key never blinks, u2f is not armed — check `journalctl --user -u omarchy-shell -n 50` or the shell's stdout for the `yubikey=true` log line from `logEvent`. Unlock with your password (still works) and re-check Task 4 Steps 3 and 5.

- [ ] **Step 9: Verify the fallbacks did not regress**

Lock three more times and confirm each path still works:

```bash
omarchy-shell lock lock   # unlock by typing your password
omarchy-shell lock lock   # unlock with your fingerprint
```

And once with the key unplugged, to confirm the retry loop does not spin when there is nothing to touch:

```bash
omarchy-shell lock lock   # key unplugged -- unlock with password
```

Expected: all three succeed. The third is the one that matters most; watch that the lock stays responsive rather than stalling on an armed-but-absent device.

- [ ] **Step 10: Commit**

```bash
cp -a ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml \
      ~/dotfiles/omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock/Service.qml
git commit -m "lock: authenticate with the YubiKey via omarchy-lock-u2f

Third PAM flow beside password and fingerprint, armed when the session
becomes secure and re-armed when the key is plugged in mid-lock. The
presence poll pauses while pam_u2f holds the token.

Verified: touch unlocks; password, fingerprint and key-absent locks all
still unlock."
```

---

### Task 5: The hardware prompt

The surface keeps Omarchy's centered field in this phase. Only the placeholder changes, so the user is told what the machine is waiting for.

**Files:**
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml`
- Modify: `~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml` (wire two `LockView` instantiations)

**Interfaces:**
- Consumes: `primaryMethod`, `u2fPamConfigured` (Task 3).
- Produces: `LockView` properties `primaryMethod` (string) and `u2fConfigured` (bool).

- [ ] **Step 1: Add the two properties to LockView**

In `LockView.qml`, after `property bool fingerprintConfigured: false` (near line 11):

```qml
  property string primaryMethod: "password"
  property bool u2fConfigured: false
```

- [ ] **Step 2: Make the placeholder follow the method**

Replace the fixed placeholder (near line 20):

```qml
  readonly property string placeholderText: "Enter Password"
```

with:

```qml
  readonly property string placeholderText: {
    if (root.primaryMethod === "yubikey") return "Touch your YubiKey"
    if (root.primaryMethod === "fingerprint") return "Place your finger on the reader"
    if (root.u2fConfigured) return "Insert your YubiKey"
    return "Enter Password"
  }
```

The `u2fConfigured` branch is what distinguishes "you have a key, it is not plugged in" from "this machine has no key" — without it, a plain password user would be told to insert hardware that does not exist.

- [ ] **Step 3: Wire the real lock surface**

In `Service.qml`, in the `LockView` inside `WlSessionLockSurface` (near line 273), add two bindings after `fingerprintConfigured`:

```qml
        fingerprintConfigured: root.fingerprintConfigured
        primaryMethod: root.primaryMethod
        u2fConfigured: root.u2fPamConfigured
```

- [ ] **Step 4: Wire the preview surface**

`LockView` is instantiated twice. In the second one, inside `PanelWindow` (near line 303), add the same two bindings after `fingerprintConfigured`:

```qml
      fingerprintConfigured: root.fingerprintConfigured
      primaryMethod: root.primaryMethod
      u2fConfigured: root.u2fPamConfigured
```

Missing this one is easy and the symptom is confusing: the real lock prompts correctly while `preview` keeps saying "Enter Password".

- [ ] **Step 5: Verify each prompt in the preview, without locking**

With the key plugged in:

```bash
omarchy-shell lock preview
```

Expected: the field reads **"Touch your YubiKey"**. Dismiss with `omarchy-shell lock hidePreview`.

Unplug the key, wait ~2s for the poll, and preview again. Expected: **"Place your finger on the reader"** (fingerprint is enrolled on this machine, so it outranks the absent key).

- [ ] **Step 6: Verify the prompt on a real lock**

With the TTY escape hatch from Task 4 Step 7 still open:

```bash
omarchy-shell lock lock
```

Expected: the lock reads "Touch your YubiKey", the key blinks, and a touch unlocks. Typing a password still works.

- [ ] **Step 7: Commit**

```bash
cp -a ~/.config/omarchy/plugins/timmy-xlent.lock/LockView.qml \
      ~/.config/omarchy/plugins/timmy-xlent.lock/Service.qml \
      ~/dotfiles/omarchy/.config/omarchy/plugins/timmy-xlent.lock/
cd ~/dotfiles
git add omarchy/.config/omarchy/plugins/timmy-xlent.lock
git commit -m "lock: prompt for whatever the machine is waiting for

Placeholder follows primaryMethod: touch the key, place a finger, or
insert the key when one is configured but absent. Bound on both LockView
instantiations so 'lock preview' matches the real surface."
```

---

### Task 6: Close out the phase

**Files:**
- Modify: `~/dotfiles/docs/superpowers/specs/2026-08-17-omarchy-lock-yubikey-port-design.md`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing code depends on.

- [ ] **Step 1: Confirm the full observable state**

```bash
omarchy version
omarchy-shell lock status | jq
jq '.disabledPlugins' ~/.config/omarchy/shell.json
```

Expected: `4.0.0-1`; status reporting `passwordPam: true`, `fingerprint: true`, `u2fPam: true`, `yubikey: true`, `primaryMethod: "yubikey"`; and `disabledPlugins` containing `omarchy.lock`.

- [ ] **Step 2: Confirm SUPER+L reaches all of this**

Press **SUPER+L**. Expected: the lock appears and the key unlocks it.

This is the end-to-end check the spec called out as blocked on Part A: `~/.local/bin/omarchy-system-lock` had to stop shadowing the stock script before the binding could reach this plugin. Part A retired it to `omarchy-system-lock.retired-20260817`. If SUPER+L does nothing, check `command -v omarchy-system-lock` resolves to `/usr/share/omarchy/bin/omarchy-system-lock`.

- [ ] **Step 3: Answer the spec's open question 2**

The spec asks whether keyring unlock regresses when no password is typed. Check:

```bash
omarchy-shell lock lock    # unlock with the key, then:
systemctl --user status gnome-keyring-daemon 2>/dev/null | head -5
secret-tool lookup foo bar; echo "exit=$?"
```

A locked keyring makes `secret-tool` prompt or fail. Record the finding in the spec's Open questions section — resolved or still open — rather than leaving the question dangling.

- [ ] **Step 4: Mark Phase 1 done in the spec and commit**

Edit the spec: note Phase 1 as implemented, record the keyring finding from Step 3, and leave Phase 2 as written.

```bash
cd ~/dotfiles
git add docs/superpowers/specs/2026-08-17-omarchy-lock-yubikey-port-design.md
git commit -m "docs: mark lock Phase 1 implemented

YubiKey unlock works end to end through SUPER+L. Records the keyring
finding for the spec's second open question. Phase 2 (the three-island
surface) is unchanged and still pending."
```

---

## Not in this plan

- **Phase 2**, the three-island surface: pills, the 120px clock, the pulsing hardware icon, entrance animation, and hiding the password field behind a deliberate action. It gets its own plan against the same spec.
- **Fcitx in the left island** (spec open question 1) — a Phase 2 decision.
- **Hiding the password field by default** (spec open question 3) — explicitly deferred to Phase 2 by the spec.
- **Stowing `hypr/`**, and porting the dead `envs.conf` / `workspaces.conf` settings. Unrelated to the lock; tracked separately.
