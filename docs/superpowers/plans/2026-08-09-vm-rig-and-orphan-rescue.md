# VM Rig and Orphan Rescue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Commit the four config files that exist on no repository, then build a
reproducible Arch VM rig with snapshot/revert so the bootstrap script of the
following plan has somewhere safe to be tested.

**Architecture:** Four untracked files are copied into `~/dotfiles` and symlinked
back, and an audit script generalizes the search that found them. A `vm/`
directory then holds small single-purpose scripts over `libvirt`: fetch the
official Arch cloud image, create a domain via `virt-install --cloud-init`, and
wrap ssh, screenshot, snapshot, and revert. All VM scripts source one `vm/lib.sh`
for configuration and shared helpers.

**Tech Stack:** bash, libvirt/virsh, virt-install 5.1.0, qemu/KVM, qcow2, Arch
Linux cloud image, cloud-init, GNU stow.

## Global Constraints

- Work on branch `omarchy-free`. `main` stays untouched. The host desktop is never the experiment.
- The host stows from `~/dotfiles` and symlinks `~/.config/quickshell/ii` into `~/source/repos/dots-hyprland`; changes to either are live on the host immediately.
- Commits are separate by concern. No `Co-Authored-By` trailer.
- VM guest username is `timmy-xlent`, matching the host. Hardcoded absolute paths such as the `ii` symlink target are therefore not exercised; cross-user portability is explicitly out of scope.
- VM specs: 4 vCPU, 8192 MB RAM, 40 GB disk, `os-variant archlinux`, storage pool `default` at `/var/lib/libvirt/images`.
- Display: `--graphics spice,gl.enable=yes` with `--video virtio,accel3d=yes`. Software-render fallback is `WLR_RENDERER_ALLOW_SOFTWARE=1` in the guest.
- Verification for this plan is by observable command output, not a test framework. Provisioning scripts that drive libvirt have no meaningful unit-test seam; each task below states the exact command and the exact expected output.

---

### Task 1: Rescue the four remaining orphans

Four files exist in `~/.config` and in no git repository. `border-colors.conf` is
what makes matugen own Hyprland's border colors; `omarchy-theme-bg-set` is the
only thing that repoints the wallpaper symlink and relaunches swaybg. Losing
either breaks a working host with no way to reconstruct it.

**Files:**
- Create: `~/dotfiles/matugen/.config/matugen/templates/hyprland/border-colors.conf`
- Create: `~/dotfiles/matugen/.config/matugen/templates/ncspot/config.toml`
- Create: `~/dotfiles/matugen/.config/matugen/templates/zen/zen-matugen.css`
- Create: `~/dotfiles/omarchy/.local/bin/omarchy-theme-bg-set`

- [ ] **Step 1: Create the branch**

```bash
cd ~/dotfiles
git checkout -b omarchy-free
git branch --show-current
```

Expected: `omarchy-free`

- [ ] **Step 2: Copy the three matugen templates into the repo**

`hyprland/` already exists in the repo as a real directory; `ncspot/` and `zen/`
do not.

```bash
cd ~/dotfiles
T=matugen/.config/matugen/templates
mkdir -p "$T/hyprland" "$T/ncspot" "$T/zen"
cp ~/.config/matugen/templates/hyprland/border-colors.conf "$T/hyprland/"
cp ~/.config/matugen/templates/ncspot/config.toml          "$T/ncspot/"
cp ~/.config/matugen/templates/zen/zen-matugen.css         "$T/zen/"
```

- [ ] **Step 3: Copy the wallpaper wrapper into the repo**

```bash
cd ~/dotfiles
mkdir -p omarchy/.local/bin
cp ~/.local/bin/omarchy-theme-bg-set omarchy/.local/bin/
chmod +x omarchy/.local/bin/omarchy-theme-bg-set
```

- [ ] **Step 4: Verify the copies are byte-identical to what is live**

```bash
cd ~/dotfiles
T=matugen/.config/matugen/templates
diff "$T/hyprland/border-colors.conf" ~/.config/matugen/templates/hyprland/border-colors.conf
diff "$T/ncspot/config.toml"          ~/.config/matugen/templates/ncspot/config.toml
diff "$T/zen/zen-matugen.css"         ~/.config/matugen/templates/zen/zen-matugen.css
diff omarchy/.local/bin/omarchy-theme-bg-set ~/.local/bin/omarchy-theme-bg-set
echo "all identical: $?"
```

Expected: no diff output, then `all identical: 0`

- [ ] **Step 5: Commit the rescue before changing anything on disk**

Commit first. If the following step goes wrong, the content is already safe.

```bash
cd ~/dotfiles
git add matugen/.config/matugen/templates/hyprland/border-colors.conf \
        matugen/.config/matugen/templates/ncspot/config.toml \
        matugen/.config/matugen/templates/zen/zen-matugen.css \
        omarchy/.local/bin/omarchy-theme-bg-set
git commit -m "matugen, omarchy: track the templates and wrapper that lived only on disk

border-colors.conf is what makes matugen own Hyprland's border colors,
and omarchy-theme-bg-set is the only thing repointing the wallpaper
symlink and relaunching swaybg. Neither was in any repository."
```

- [ ] **Step 6: Replace the live files with symlinks into the repo**

This makes ownership unambiguous, matching how `chromium`, `iris`, and `kitty`
are already wired. Replace whole directories for `ncspot` and `zen`; `hyprland/`
holds upstream-derived files too, so only the one file is linked.

```bash
cd ~/.config/matugen/templates
rm -rf ncspot zen
# Three levels up from templates/ reaches $HOME, matching the existing
# chromium/iris/kitty symlinks. Verify with: readlink chromium
ln -s "../../../dotfiles/matugen/.config/matugen/templates/ncspot" ncspot
ln -s "../../../dotfiles/matugen/.config/matugen/templates/zen" zen
# Four levels from templates/hyprland/, one deeper.
rm hyprland/border-colors.conf
ln -s "../../../../dotfiles/matugen/.config/matugen/templates/hyprland/border-colors.conf" hyprland/border-colors.conf
rm ~/.local/bin/omarchy-theme-bg-set
ln -s ~/dotfiles/omarchy/.local/bin/omarchy-theme-bg-set ~/.local/bin/omarchy-theme-bg-set
```

- [ ] **Step 7: Verify every symlink resolves and content is unchanged**

```bash
for p in ~/.config/matugen/templates/ncspot/config.toml \
         ~/.config/matugen/templates/zen/zen-matugen.css \
         ~/.config/matugen/templates/hyprland/border-colors.conf \
         ~/.local/bin/omarchy-theme-bg-set; do
  printf '%-64s %s\n' "$p" "$([ -f "$p" ] && echo OK || echo BROKEN)"
done
```

Expected: four lines, all `OK`

- [ ] **Step 8: Prove the wallpaper pipeline still works end to end**

This exercises the wrapper through its symlink. Run it, then confirm the
generated border colors changed.

```bash
md5sum ~/.config/hypr/colors-ii.conf
qs -c ii ipc call wallpapers apply "$(readlink -f ~/.config/omarchy/current/background)" 2>/dev/null || \
  ~/.config/quickshell/ii/scripts/colors/switchwall.sh --mode dark --image "$(readlink -f ~/.config/omarchy/current/background)"
sleep 5
md5sum ~/.config/hypr/colors-ii.conf
pgrep -af swaybg
```

Expected: `colors-ii.conf` still exists and is non-empty, and `swaybg` is running
with an `-i` path. The wallpaper is unchanged so the checksum may match; the
point is that the pipeline completes without error and swaybg survives.

- [ ] **Step 9: Confirm nothing further needs committing**

The symlinks live in `~/.config`, outside the repository, so this step changes
nothing tracked. Verify that rather than making an empty commit.

```bash
cd ~/dotfiles
git status --short
```

Expected: no output. The rescue was already committed in Step 5.

---

### Task 2: Audit script for untracked config

Eight orphans surfaced from two ad-hoc checks. That hit rate is the argument for
automating the search rather than assuming eight is the whole list.

**Files:**
- Create: `~/dotfiles/bin/.local/bin/dotfiles-audit`

**Interfaces:**
- Produces: an executable `dotfiles-audit` on `PATH` after stow, exiting `1` when any orphan is found so it can gate later work.

- [ ] **Step 1: Write the audit script**

```bash
#!/usr/bin/env bash
# dotfiles-audit — report live config paths that no repository tracks.
#
# Exits 1 if any orphan or broken link is found, so it can be used as a gate.
set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
IIREPO="${IIREPO:-$HOME/source/repos/dots-hyprland}"

found_problem=0

tracked_in() { # repo abs_path
  local repo=$1 path=$2 rel
  [[ "$path" == "$repo/"* ]] || return 1
  rel="${path#"$repo"/}"
  git -C "$repo" ls-files --error-unmatch "$rel" >/dev/null 2>&1
}

check() { # label target
  local label=$1 target=$2 real
  if [[ ! -e "$target" ]]; then
    printf 'BROKEN   %-12s %s\n' "$label" "$target"
    found_problem=1
    return
  fi
  real=$(readlink -f "$target")
  if tracked_in "$DOTFILES" "$real"; then
    printf 'dotfiles %-12s %s\n' "$label" "$target"
  elif tracked_in "$IIREPO" "$real"; then
    printf 'ii       %-12s %s\n' "$label" "$target"
  else
    printf 'ORPHAN   %-12s %s -> %s\n' "$label" "$target" "$real"
    found_problem=1
  fi
}

# matugen template inputs, read from the config that references them
if [[ -f "$HOME/.config/matugen/config.toml" ]]; then
  while read -r p; do
    check matugen "${p/#\~/$HOME}"
  done < <(grep -oP "input_path = '\K[^']+" "$HOME/.config/matugen/config.toml")
fi

# user scripts on PATH
for f in "$HOME"/.local/bin/*; do
  [[ -e "$f" ]] && check bin "$f"
done

# files sourced by hypr configs
for conf in "$HOME"/.config/hypr/*.conf; do
  [[ -f "$conf" ]] || continue
  while read -r p; do
    [[ "$p" == /* || "$p" == "~"* ]] || continue
    check hypr-source "${p/#\~/$HOME}"
  done < <(grep -oP '^\s*source\s*=\s*\K\S+' "$conf")
done

if (( found_problem )); then
  echo
  echo "Untracked or broken paths found. Commit them before relying on a rebuild."
fi
exit "$found_problem"
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x ~/dotfiles/bin/.local/bin/dotfiles-audit
~/dotfiles/bin/.local/bin/dotfiles-audit; echo "exit=$?"
```

Expected: a table of `dotfiles` / `ii` rows. Any `ORPHAN` row is a real finding —
triage it before continuing. Rows pointing into `~/.local/share/omarchy` are
expected at this stage and are what Phase 2 removes.

- [ ] **Step 3: Confirm it exits non-zero when an orphan exists**

```bash
touch ~/.local/bin/zzz-audit-probe
~/dotfiles/bin/.local/bin/dotfiles-audit | grep zzz-audit-probe
~/dotfiles/bin/.local/bin/dotfiles-audit >/dev/null; echo "exit=$?"
rm ~/.local/bin/zzz-audit-probe
```

Expected: the probe appears on an `ORPHAN` line, then `exit=1`

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add bin/.local/bin/dotfiles-audit
git commit -m "bin: add dotfiles-audit to find config no repo tracks

Eight untracked files surfaced from two ad-hoc checks while planning the
omarchy-free bootstrap. Exits non-zero on any orphan so it can gate a
rebuild."
```

---

### Task 3: VM configuration and image fetch

**Files:**
- Create: `~/dotfiles/vm/lib.sh`
- Create: `~/dotfiles/vm/fetch-image.sh`

**Interfaces:**
- Produces: `vm/lib.sh` exporting `VM_NAME`, `VM_MEM`, `VM_VCPUS`, `VM_DISK_GB`, `VM_USER`, `POOL_DIR`, `IMAGE_URL`, `IMAGE_CACHE`, `VM_DISK`, and functions `die msg require_tool vm_exists vm_ip`. Every later `vm/` script sources it.

- [ ] **Step 1: Write vm/lib.sh**

```bash
#!/usr/bin/env bash
# Shared configuration and helpers for the Arch test VM.
# Every value can be overridden from the environment.

VM_NAME="${VM_NAME:-arch-bootstrap}"
VM_MEM="${VM_MEM:-8192}"
VM_VCPUS="${VM_VCPUS:-4}"
VM_DISK_GB="${VM_DISK_GB:-40}"
VM_USER="${VM_USER:-timmy-xlent}"

POOL_DIR="${POOL_DIR:-/var/lib/libvirt/images}"
VM_DISK="${VM_DISK:-$POOL_DIR/$VM_NAME.qcow2}"

IMAGE_URL="${IMAGE_URL:-https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2}"
IMAGE_CACHE="${IMAGE_CACHE:-$HOME/.cache/arch-bootstrap/Arch-Linux-x86_64-cloudimg.qcow2}"

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

# Write operations (define, snapshot, destroy) need org.libvirt.unix.manage,
# which Arch's polkit rule grants only to the 'libvirt' group. This user is not
# in it, so bare virsh would hit an interactive polkit prompt and break
# scripting. sudo is used consistently instead.
# Alternative long-term setup: usermod -aG libvirt "$USER" and re-login, then
# drop the sudo here.
VIRSH=(sudo virsh -c qemu:///system)

msg() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31m==> %s\033[0m\n' "$*" >&2; exit 1; }

require_tool() {
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
  done
}

vm_exists() { "${VIRSH[@]}" dominfo "$VM_NAME" >/dev/null 2>&1; }

# Print the VM's IPv4 address, or nothing if it has none yet.
vm_ip() {
  "${VIRSH[@]}" domifaddr "$VM_NAME" 2>/dev/null |
    grep -oP '\d+\.\d+\.\d+\.\d+(?=/)' | head -1
}
```

- [ ] **Step 2: Write vm/fetch-image.sh**

Downloads once and caches. The image is ~556 MB; re-running must not re-download.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_tool curl

if [[ -f "$IMAGE_CACHE" ]]; then
  msg "image already cached: $IMAGE_CACHE ($(du -h "$IMAGE_CACHE" | cut -f1))"
  exit 0
fi

mkdir -p "$(dirname "$IMAGE_CACHE")"
msg "downloading $IMAGE_URL"
curl -fL --progress-bar -o "$IMAGE_CACHE.part" "$IMAGE_URL"
mv "$IMAGE_CACHE.part" "$IMAGE_CACHE"
msg "cached at $IMAGE_CACHE ($(du -h "$IMAGE_CACHE" | cut -f1))"
```

- [ ] **Step 3: Run the fetch and verify the image is a qcow2**

```bash
chmod +x ~/dotfiles/vm/fetch-image.sh
~/dotfiles/vm/fetch-image.sh
qemu-img info ~/.cache/arch-bootstrap/Arch-Linux-x86_64-cloudimg.qcow2 | head -4
```

Expected: `file format: qcow2` and a virtual size around 10 GiB

- [ ] **Step 4: Verify the fetch is idempotent**

```bash
~/dotfiles/vm/fetch-image.sh
```

Expected: `==> image already cached: ...` and an immediate exit, no download bar

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add vm/lib.sh vm/fetch-image.sh
git commit -m "vm: add shared config and cloud image fetch

Caches the official Arch cloud image so VM recreation does not re-download
556MB each time."
```

---

### Task 4: Create the VM

**Files:**
- Create: `~/dotfiles/vm/cloud-init/user-data`
- Create: `~/dotfiles/vm/create.sh`

**Interfaces:**
- Consumes: `vm/lib.sh` from Task 3.
- Produces: a running libvirt domain named by `$VM_NAME`, reachable over ssh as `$VM_USER` with `$SSH_KEY`.

- [ ] **Step 1: Write the cloud-init user-data**

The guest user matches the host username so absolute paths in the configs
resolve. `openssh` is already present in the cloud image; `git` is needed before
anything else can be cloned.

```yaml
#cloud-config
users:
  - name: timmy-xlent
    groups: [wheel]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - SSH_KEY_PLACEHOLDER

ssh_pwauth: false

packages:
  - git

runcmd:
  - [ systemctl, enable, --now, sshd ]
```

- [ ] **Step 2: Write vm/create.sh**

The placeholder is substituted at run time so the public key is never committed.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_tool virt-install qemu-img virsh

[[ -f "$SSH_KEY.pub" ]] || die "no ssh public key at $SSH_KEY.pub"
[[ -f "$IMAGE_CACHE" ]] || die "no cached image; run ./fetch-image.sh first"

if vm_exists; then
  die "$VM_NAME already exists. Destroy it first: ./destroy.sh"
fi

msg "creating $VM_DISK_GB GB disk backed by the cloud image"
sudo cp "$IMAGE_CACHE" "$VM_DISK"
sudo qemu-img resize "$VM_DISK" "${VM_DISK_GB}G"

USER_DATA=$(mktemp)
trap 'rm -f "$USER_DATA"' EXIT
sed "s|SSH_KEY_PLACEHOLDER|$(cat "$SSH_KEY.pub")|" cloud-init/user-data > "$USER_DATA"

msg "creating domain $VM_NAME"
sudo virt-install \
  --connect qemu:///system \
  --name "$VM_NAME" \
  --memory "$VM_MEM" \
  --vcpus "$VM_VCPUS" \
  --cpu host-passthrough \
  --disk "path=$VM_DISK,format=qcow2,bus=virtio" \
  --import \
  --os-variant archlinux \
  --network network=default,model=virtio \
  --graphics spice,gl.enable=yes \
  --video virtio,accel3d=yes \
  --channel spicevmc \
  --cloud-init "user-data=$USER_DATA" \
  --noautoconsole

msg "waiting for an IP address"
for _ in $(seq 1 60); do
  ip=$(vm_ip)
  [[ -n "$ip" ]] && break
  sleep 2
done
[[ -n "${ip:-}" ]] || die "no IP after 120s; check: virsh console $VM_NAME"
msg "$VM_NAME is up at $ip"
```

- [ ] **Step 3: Create the VM**

```bash
chmod +x ~/dotfiles/vm/create.sh
~/dotfiles/vm/create.sh
```

Expected: ends with `==> arch-bootstrap is up at 192.168.122.x`

If it times out waiting for an IP, attach to the console with
`sudo virsh -c qemu:///system console arch-bootstrap` to read cloud-init output.
Detach with `Ctrl+]`.

- [ ] **Step 4: Verify ssh works and the guest is Arch**

```bash
IP=$(sudo virsh -c qemu:///system domifaddr arch-bootstrap | grep -oP '\d+\.\d+\.\d+\.\d+(?=/)')
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 timmy-xlent@"$IP" \
  'head -2 /etc/os-release; whoami; sudo -n true && echo "sudo ok"'
```

Expected:
```
NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
timmy-xlent
sudo ok
```

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add vm/cloud-init/user-data vm/create.sh
git commit -m "vm: create the Arch test VM via virt-install and cloud-init

Guest username matches the host so absolute paths in the configs resolve.
The ssh public key is substituted at run time, never committed."
```

---

### Task 5: ssh, screenshot, and destroy helpers

**Files:**
- Create: `~/dotfiles/vm/sh.sh`
- Create: `~/dotfiles/vm/shot.sh`
- Create: `~/dotfiles/vm/destroy.sh`

**Interfaces:**
- Consumes: `vm/lib.sh` from Task 3, a running domain from Task 4.
- Produces: `vm/sh.sh [command...]` runs a command in the guest or opens a shell; `vm/shot.sh [out.png]` writes a screenshot on the host.

- [ ] **Step 1: Write vm/sh.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

ip=$(vm_ip)
[[ -n "$ip" ]] || die "$VM_NAME has no IP; is it running?"

exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -i "$SSH_KEY" "$VM_USER@$ip" "$@"
```

- [ ] **Step 2: Write vm/shot.sh**

`virsh screenshot` captures the guest framebuffer from the host, so it needs
neither a working ssh session nor `grim` in the guest — which is exactly the
situation when the shell has failed to start.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

require_tool virsh
out="${1:-/tmp/$VM_NAME-$(date +%H%M%S).png}"
raw=$(mktemp --suffix=.ppm)
trap 'rm -f "$raw"' EXIT

"${VIRSH[@]}" screenshot "$VM_NAME" "$raw" >/dev/null

if command -v magick >/dev/null 2>&1; then
  magick "$raw" "$out"
elif command -v convert >/dev/null 2>&1; then
  convert "$raw" "$out"
else
  out="${out%.png}.ppm"
  cp "$raw" "$out"
  msg "imagemagick not installed; wrote raw PPM"
fi
msg "wrote $out"
```

- [ ] **Step 3: Write vm/destroy.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

vm_exists || { msg "$VM_NAME does not exist"; exit 0; }

read -rp "Destroy $VM_NAME and its disk? [y/N] " reply
[[ "$reply" == [yY] ]] || { msg "aborted"; exit 0; }

"${VIRSH[@]}" destroy "$VM_NAME" 2>/dev/null || true
"${VIRSH[@]}" undefine "$VM_NAME" --nvram --snapshots-metadata --remove-all-storage
msg "destroyed $VM_NAME"
```

- [ ] **Step 4: Verify all three**

```bash
chmod +x ~/dotfiles/vm/sh.sh ~/dotfiles/vm/shot.sh ~/dotfiles/vm/destroy.sh
~/dotfiles/vm/sh.sh 'uname -r; nproc; free -m | awk "/Mem:/ {print \$2\" MB\"}"'
~/dotfiles/vm/shot.sh /tmp/vm-check.png
file /tmp/vm-check.png
```

Expected: a kernel version, `4`, roughly `7900 MB`, then a PNG (or PPM) image
file. Do not run `destroy.sh` yet.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add vm/sh.sh vm/shot.sh vm/destroy.sh
git commit -m "vm: add ssh, screenshot and destroy helpers

Screenshots come from virsh on the host rather than grim in the guest, so
they still work when the guest shell has failed to start."
```

---

### Task 6: Snapshot and revert, and take the base snapshot

Reverting is what makes iterating on the bootstrap script tolerable. Internal
qcow2 snapshots on a shut-off domain are fast and need no external state.

**Files:**
- Create: `~/dotfiles/vm/snap.sh`
- Create: `~/dotfiles/vm/revert.sh`
- Create: `~/dotfiles/vm/README.md`

**Interfaces:**
- Consumes: `vm/lib.sh` from Task 3, a running domain from Task 4.
- Produces: `vm/snap.sh <name> [description]` and `vm/revert.sh <name>`; a snapshot named `base` exists after this task.

- [ ] **Step 1: Write vm/snap.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

name="${1:?usage: snap.sh <name> [description]}"
desc="${2:-$name}"

vm_exists || die "$VM_NAME does not exist"

if "${VIRSH[@]}" domstate "$VM_NAME" | grep -q running; then
  msg "shutting down $VM_NAME for a clean snapshot"
  "${VIRSH[@]}" shutdown "$VM_NAME" >/dev/null
  for _ in $(seq 1 60); do
    "${VIRSH[@]}" domstate "$VM_NAME" | grep -q 'shut off' && break
    sleep 2
  done
  "${VIRSH[@]}" domstate "$VM_NAME" | grep -q 'shut off' || \
    die "did not shut down in 120s"
fi

"${VIRSH[@]}" snapshot-delete "$VM_NAME" "$name" >/dev/null 2>&1 || true
"${VIRSH[@]}" snapshot-create-as "$VM_NAME" "$name" "$desc"
msg "snapshot '$name' created"
"${VIRSH[@]}" snapshot-list "$VM_NAME"
```

- [ ] **Step 2: Write vm/revert.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh

name="${1:?usage: revert.sh <name>}"
vm_exists || die "$VM_NAME does not exist"

"${VIRSH[@]}" snapshot-info "$VM_NAME" "$name" >/dev/null 2>&1 || \
  die "no snapshot named '$name'"

"${VIRSH[@]}" destroy "$VM_NAME" 2>/dev/null || true
"${VIRSH[@]}" snapshot-revert "$VM_NAME" "$name" --running
msg "reverted to '$name'"

msg "waiting for an IP address"
for _ in $(seq 1 60); do
  ip=$(vm_ip)
  [[ -n "$ip" ]] && break
  sleep 2
done
[[ -n "${ip:-}" ]] || die "no IP after 120s"
msg "$VM_NAME is up at $ip"
```

- [ ] **Step 3: Take the base snapshot**

```bash
chmod +x ~/dotfiles/vm/snap.sh ~/dotfiles/vm/revert.sh
~/dotfiles/vm/snap.sh base "clean Arch, post cloud-init"
```

Expected: `==> snapshot 'base' created`, then a table listing `base`

- [ ] **Step 4: Prove revert actually reverts**

Write a marker, revert, and confirm the marker is gone. This is the single most
important verification in this plan — the whole iteration loop depends on it.

```bash
~/dotfiles/vm/revert.sh base
~/dotfiles/vm/sh.sh 'touch ~/MARKER && ls ~/MARKER'
~/dotfiles/vm/revert.sh base
~/dotfiles/vm/sh.sh 'ls ~/MARKER 2>&1 || echo "MARKER GONE - revert works"'
```

Expected: `/home/timmy-xlent/MARKER` on the first check, then
`MARKER GONE - revert works` after the revert.

- [ ] **Step 5: Time a revert cycle**

Records the actual iteration cost, which decides whether the second `deps`
snapshot in the next plan is worth taking.

```bash
time ~/dotfiles/vm/revert.sh base
```

Expected: well under a minute. Note the figure in the commit message.

- [ ] **Step 6: Write vm/README.md**

```markdown
# Arch test VM

A throwaway Arch VM for testing the bootstrap script without touching the
daily driver.

## Usage

    ./fetch-image.sh          # download and cache the Arch cloud image (once)
    ./create.sh               # create and boot the VM
    ./snap.sh base "clean"    # snapshot (shuts the VM down first)
    ./revert.sh base          # revert and reboot
    ./sh.sh [command]         # ssh into the guest, or run one command
    ./shot.sh [out.png]       # screenshot the guest framebuffer from the host
    ./destroy.sh              # remove the VM and its disk

Every setting in `lib.sh` can be overridden from the environment:

    VM_NAME=scratch VM_MEM=4096 ./create.sh

## Notes

The guest username matches the host so absolute paths in the configs
resolve. Cross-user portability is deliberately not exercised.

Screenshots come from `virsh screenshot` on the host, not `grim` in the
guest, so they still work when the shell has failed to start.

Snapshots require the VM to be shut off, which `snap.sh` handles. Reverting
boots the VM back up.

If Hyprland fails to start under virgl, set `WLR_RENDERER_ALLOW_SOFTWARE=1`
in the guest to fall back to software rendering.
```

- [ ] **Step 7: Commit**

Substitute the figure measured in Step 5 for `<N>` before committing.

```bash
cd ~/dotfiles
git add vm/snap.sh vm/revert.sh vm/README.md
git commit -m "vm: add snapshot and revert, and document the rig

Revert is verified by writing a marker file, reverting, and confirming it
is gone. A full revert cycle takes about <N> seconds."
```

---

## Done when

- `dotfiles-audit` reports no `ORPHAN` rows outside `~/.local/share/omarchy`
- `vm/create.sh` produces a booting Arch VM reachable via `vm/sh.sh`
- `vm/revert.sh base` demonstrably discards guest changes
- The host's wallpaper pipeline still works after the symlink switch in Task 1

## Next plan

Phases 2–4 of the spec: vendor the hypr defaults, retarget theming onto matugen,
write the staged `install.sh`, and iterate against this rig until the five
verification checks pass. That plan adds a `deps` snapshot taken after the
dependency stage so the slow meta-package build is paid once.
