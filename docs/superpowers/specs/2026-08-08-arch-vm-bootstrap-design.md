# Omarchy-free Arch bootstrap

**Date:** 2026-08-08
**Status:** approved, not yet implemented

## Goal

Produce `~/dotfiles/install.sh`: a script that takes a fresh Arch Linux machine to
this Hyprland + quickshell + CLI environment with no dependency on omarchy. A
throwaway Arch VM serves as the test rig; the script is the deliverable.

## Why this is not currently possible

An audit of `~/.config/matugen` against both source repos found that the matugen
layer — which this design promotes to the single source of truth for colors — is
almost entirely uncommitted. Of the 14 template inputs `config.toml` references,
only `chromium` is tracked in git.

Three files exist on this machine and in no repository at all:

- `templates/hyprland/border-colors.conf` — generates `~/.config/hypr/colors-ii.conf`
- `templates/ncspot/config.toml`
- `templates/zen/zen-matugen.css`

`border-colors.conf` is load-bearing: it is what makes matugen own Hyprland's
border colors, and therefore what replaces omarchy's theme in this design.

The remaining templates are byte-identical copies of upstream dots-hyprland,
placed by its installer, and are reproducible.

## Constraints

**The host must never be the experiment.** `~/dotfiles` is stowed into the live
desktop, so making it omarchy-free edits the daily driver. All decoupling work
happens on an `omarchy-free` branch. The VM clones that branch. `main` stays
untouched until the VM proves the result.

**Migrating the host off omarchy is out of scope.** The script can be proven
correct in the VM while the daily driver stays on omarchy indefinitely. That
migration is a separate, deliberate act with its own risk profile.

## Scope

In scope: Hyprland, quickshell (`ii` + `bar`), kitty, matugen theming, zsh, and
CLI tooling (nvim, yazi, fzf, and similar).

Out of scope: GUI applications (Signal, Spotify, 1Password, Teams webapps).
These are personal rather than structural.

## Decisions

| Decision | Choice |
|---|---|
| Decoupling depth | Fully omarchy-free |
| Hypr defaults | Vendor into `~/dotfiles` |
| Theming | matugen replaces omarchy's theme dir as source of truth |
| `omarchy-menu` (891 lines) | Drop; rewire bar's call sites |
| VM provisioning | Official Arch cloud image + cloud-init |
| Script location | Inside `~/dotfiles`, staged and idempotent |
| Implementation | Thin bash + plain-text package lists |
| Display | `virtio-gpu-gl` + SPICE, software-render fallback |
| Progress reporting | Dependency-free `lib/ui.sh` |

### On the implementation mechanism

Bootstrapping decomposes into two halves. Package installation is already
declarative and already solved — pacman resolves graphs, and dots-hyprland ships
14 `illogical-impulse-*` meta-packages with real `depends=()` arrays. Config
placement is roughly five commands. The honest size of the glue is ~150 lines,
and it is idempotent largely for free: `pacman -S --needed`, `stow --restow`,
`git clone || git pull`, and matugen.

Ansible was considered and rejected: it buys most of its value across many
machines, and would roughly triple the line count in YAML while adding a Python
bootstrap step. Nix would mean abandoning pacman/AUR for the shell stack, making
upstream's meta-packages dead weight. chezmoi solves the other half — templating
and per-machine variance — and would replace stow rather than the installer.

**Structural rule against bash rot:** package sets live in plain-text list files,
never inline in the script. Any stage exceeding ~40 lines means that stage's
content belongs in a declarative file instead. The script orchestrates; it never
becomes the manifest.

Bash's real weakness is that it cannot be tested without being run, and running
it mutates the machine. The VM snapshot rig is the direct antidote.

## Repositories

Two repositories make up the environment:

| Repo | Role | Placement |
|---|---|---|
| `timvi402/dotfiles` | This repo. hypr, kitty, matugen, nvim, walker, zsh | stowed into `~` |
| `timvi402/dots-hyprland` | The `ii` shell plus the 14 dependency meta-packages and their installer | `~/source/repos/`, with `~/.config/quickshell/ii` symlinked into it |

`timvi402/qs-config` (the `bar` shell) is **archived and out of scope**. It is not
running, has four commits, and was last touched ten weeks ago. Decoupling a shell
that is not in use would be wasted work, and it accounted for 12 of the omarchy
references originally inventoried.

### Ownership boundaries

The one structural defect worth fixing as part of this work is that
`~/.config/matugen/templates/` has no owner. Files arrive from two directions —
symlinks out of `dotfiles`, and copies placed by dots-hyprland's installer — so
neither repo owns the directory. That gap is the direct cause of the orphaned
templates described above: when new templates were added there was no obvious
home for them.

**`dotfiles` owns matugen entirely.** All 14 templates are vendored and stowed
from here, and dots-hyprland's installer no longer supplies them.

dots-hyprland does not track upstream illogical-impulse; there is no upstream
remote configured, and `sdata/subcmd-install`, `sdata/lib`, and both distro
dependency directories have already been modified locally. It is treated as owned
code with upstream ancestry, not as a fork to be kept rebasable. It stays a
separate repository because it carries the dependency meta-packages and their
installer, which are a distinct concern from user configuration — not because of
any merge constraint.

Merging the two repositories is therefore possible but deliberately deferred.
Revisit once the bootstrap works and the split has been observed to help or hurt.

## Coupling inventory

Measured against the live host:

| Component | omarchy references | Severity |
|---|---|---|
| `ii` (dots-hyprland) | 4, all in `switchwall.sh` | Trivial — already guarded with `command -v … &&` |
| `~/dotfiles/hypr` | 9 `source =` lines plus theme | Blocking — no bindings, envs, looknfeel, or theme |
| `~/dotfiles` zsh, bash, walker | ~25 | Unknown until triaged |
| ~~`bar` (qs-config)~~ | ~~12~~ | Archived, out of scope |

Quickshell is nearly omarchy-free already. The Hyprland configuration is not.

## Phases

    Phase 0  Reconcile the dotfiles tree                    prerequisite
    Phase 1  Build VM rig -> clean-base snapshot            independent of 2
    Phase 2  Decouple ~/dotfiles from omarchy, on a branch
    Phase 3  Write staged install.sh
    Phase 4  Iterate: revert -> install -> screenshot -> fix

Phases 1 and 2 have no dependency on each other.

## Components

| Component | Owns | Depends on |
|---|---|---|
| VM rig (`vm/`) | Provisioning, snapshot/revert, SSH + screenshot helpers | libvirt, cloud image |
| Bootstrap (`install.sh`, `stages/`) | Package install, stow, matugen first run | dots-hyprland `setup install-deps` |
| Decoupled configs (`hypr/`, `matugen/`) | Vendored hypr defaults, matugen colors | nothing omarchy |

The rig is throwaway scaffolding; the other two are the lasting artifact. Keeping
the rig in `vm/` rather than woven into `install.sh` means the script never
carries VM-specific assumptions — it is the same script a real machine runs.

## Phase 0 — reconcile the tree

`~/dotfiles` currently has a dirty working tree. All of the following must be
committed before any decoupling begins, in separate commits by concern:

Untracked, sitting in the repo directory:

- `matugen/.config/matugen/templates/iris/theme.toml`
- `matugen/.config/matugen/templates/kitty/colors.conf`
- `zsh/.p10k-colors.zsh`
- `zsh/.zsh_fzf_theme`

Not in any repository — copy in from `~/.config/matugen/templates/`:

- `hyprland/border-colors.conf`
- `ncspot/config.toml`
- `zen/zen-matugen.css`

Also not in any repository, and load-bearing for the wallpaper pipeline (see B5):

- `~/.local/bin/omarchy-theme-bg-set` — a local wrapper around omarchy's binary of
  the same name, not omarchy's own. Commit it as-is to preserve the working host,
  then supersede it in B5.

Modified and uncommitted: `.gitignore`, `kitty/.config/kitty/kitty.conf`,
`matugen/.config/matugen/config.toml`, `zsh/.p10k.zsh`, `zsh/.zsh_pw_search`,
`zsh/.zshrc`.

Once committed, symlink the three rescued templates into `~/.config/matugen/`
following the existing `chromium`/`iris`/`kitty` pattern, so ownership is
unambiguous rather than "a real directory that happens to sit there".

Finally, write a small audit script generalizing how these were found: for every
path referenced by a config, report whether it is tracked in either repo. Run it
once and triage the output.

Eight orphans surfaced from two ad-hoc checks — the matugen template audit and
tracing one `switchwall.sh` call. That hit rate is the strongest argument for
automating the search rather than trusting that eight is the whole list.

## Phase 1 — VM rig

`vm/` contains:

- `create.sh` — fetch `Arch-Linux-x86_64-cloudimg.qcow2`, build a cloud-init seed
  ISO (user, SSH key, passwordless sudo), `virt-install` with `virtio-gpu-gl` and
  SPICE. 4 vCPU, 8 GB RAM, 40 GB disk.
- `snap.sh <name>` / `revert.sh <name>` — libvirt snapshots
- `sh.sh` — SSH wrapper
- `shot.sh` — `grim` over SSH, pull the PNG back

**Two snapshots, not one.** This decides whether iteration is tolerable:

- `base` — clean Arch, post cloud-init
- `deps` — taken after stage 10

The 14 `illogical-impulse-*` meta-packages compile from source and
`quickshell-git` is slow. Iterating on stages 20–40 reverts to `deps`, turning a
~20-minute cycle into seconds. Only changes to the package lists need `base`.

## Phase 2 — decoupling

| # | Work | Size |
|---|---|---|
| B1 | Vendor 9 hypr defaults to `hypr/.config/hypr/defaults/`, stripping `omarchy-*` calls | 472 lines |
| B2 | Retarget theming onto matugen | 3 files |
| B3 | Vendor 15 helpers to `bin/.local/bin/`, drop the `omarchy-` prefix, update call sites | ~264 lines |
| ~~B4~~ | ~~Drop `omarchy-menu`; rewire 4 bar call sites~~ — dropped with qs-config | — |
| B5 | `switchwall.sh`: add a dotfiles-owned wallpaper pointer and swaybg relaunch alongside the existing guarded omarchy call | see below |
| B6 | Host/VM variance: gitignored `hypr/local.conf` plus `.example` | new |
| B7 | Triage remaining ~25 omarchy references in zsh, bash, walker | audit |

### B1 — files to vendor

`autostart.conf` (16), `bindings/media.conf` (30), `bindings/clipboard.conf` (5),
`bindings/tiling-v2.conf` (133), `bindings/utilities.conf` (76), `envs.conf` (33),
`looknfeel.conf` (143), `input.conf` (21), `windows.conf` (15).

### B2 — theming detail

- `hyprland.conf` — drop the omarchy theme `source` line. matugen's
  `colors-ii.conf` is already a strict superset; it adds inactive border colors
  that omarchy's 6-line theme file does not define.
- `hyprlock.conf` — **rewrite, do not redirect.** The variable names do not
  match. omarchy defines `$color`, `$inner_color`, `$outer_color`, `$font_color`,
  `$check_color`; matugen emits `$text_color`, `$entry_background_color`,
  `$entry_border_color`, `$entry_color`. matugen also already emits
  `$background_image` with a resolved path, which cleanly replaces the
  `~/.config/omarchy/current/background` symlink indirection.
- `kitty.conf` — drop the omarchy base include. `colors-matugen.conf` becomes the
  sole source rather than an override layered on top.

### B3 — helpers to vendor

`launch-screensaver` (59), `cmd-terminal-cwd` (21), `launch-browser` (17),
`launch-editor` (15), `launch-tui` (6), `launch-or-focus` (19),
`launch-or-focus-tui` (9), `launch-webapp` (13), `launch-or-focus-webapp` (15),
`weather-icon` (36), `weather-status` (17), `launch-audio` (5),
`launch-bluetooth` (6), `launch-wifi` (6), `theme-bg-set` (20).

`hypridle.conf` references `omarchy-lock-screen`, which does not exist on this
machine — that binding is already dead on the host today, independent of this
work. Vendoring replaces it with a direct `hyprlock` call.

### B5 — wallpaper, and why this one adds rather than deletes

The wallpaper is painted by `swaybg`, launched from omarchy's `autostart.conf`
against `~/.config/omarchy/current/background`. `omarchy-theme-bg-set` is the only
thing that repoints that symlink and relaunches swaybg. Removing the call from
`switchwall.sh` would silently break wallpaper switching on the host.

The host is affected because it symlinks `~/.config/quickshell/ii` into
dots-hyprland, so any change to `switchwall.sh` is live immediately — while the
host continues sourcing *omarchy's* `autostart.conf` until the Phase 5 migration
that this spec puts out of scope. Deleting during Phase 2 would leave swaybg
pointed at a symlink nothing updates.

Therefore `switchwall.sh` gains, alongside the existing guarded omarchy call:

- a dotfiles-owned wallpaper pointer, repointed on each switch
- its own `swaybg` relaunch against that pointer

The vendored `autostart.conf` from B1 launches swaybg against the same pointer.
The guarded omarchy call is already a no-op where omarchy is absent, so the VM
takes the new path and the host keeps both. The omarchy line is removed only at
host migration, which is out of scope here.

**`omarchy-theme-bg-set` on `PATH` is a local wrapper, not omarchy's binary**, and
it is orphan #8 — `~/.local/bin/omarchy-theme-bg-set`, tracked in no repository.
Reading it shows the current flow duplicates work: the wrapper writes
`.background.wallpaperPath` into ii's `config.json` immediately after
`switchwall.sh` has already called `set_wallpaper_path`, and runs `matugen` a
second time. **Per wallpaper change, matugen runs twice and `config.json` is
written twice.** Only the symlink-and-swaybg step is unique to the wrapper, so
implementing B5 also removes that duplicated work.

### B6 — per-machine variance

`hyprland.conf` hardcodes NVIDIA environment variables that are wrong in a VM,
and `monitors.conf` is host-specific. A gitignored `hypr/local.conf`, sourced
last, is the bash-idiom answer to the variance problem chezmoi would have solved
with templates. Ship a `local.conf.example` alongside it.

## Phase 3 — the script

    install.sh              orchestrator: --from N, --only N, --dry-run, --verbose
    lib/ui.sh               progress reporting
    stages/00-base.sh       pacman -Syu, base-devel, git, stow, paru
    stages/10-shell.sh      calls dots-hyprland ./setup install-deps
    stages/20-dotfiles.sh   stow trees, symlink ii
    stages/30-theme.sh      matugen first run
    stages/40-cli.sh        nvim, zsh, yazi, fzf
    packages/base.txt
    packages/shell.txt
    packages/cli.txt
    packages/aur.txt

Stage 10 calls dots-hyprland's own `setup install-deps` rather than
reimplementing dependency installation. Logs go to
`~/.local/state/dotfiles-install.log`. Failures stop immediately, naming the
stage; `--from N` resumes.

### Progress reporting

`lib/ui.sh` is dependency-free (~50 lines), because stage 00 runs before anything
is installed and therefore cannot rely on tooling it has not yet installed. It
provides `ui::stage`, `ui::run`, `ui::ok`, `ui::skip`, `ui::fail`, `ui::summary`.

Required behaviors:

- **TTY detection** (`[[ -t 1 ]]`) — spinners and rules when interactive, flat
  one-line-per-event when piped. Same script, no `--ci` flag.
- **`NO_COLOR` respected**, per the no-color.org convention.
- **Console/log split** — console shows one line per step; full command output
  always lands in the log. `--verbose` streams both.
- **Skip visually distinct from success** — `·  already present` versus `✓`. On an
  idempotent installer this is the highest-value signal available: a re-run that
  is all `·` shows at a glance that nothing drifted.
- **Live elapsed time on long steps** — `quickshell-git` can run 20 minutes, and a
  frozen terminal is indistinguishable from a hang.
- **Inline log tail on failure**, plus the exact `--from` command to resume.
  Requiring someone to go open a file to learn what broke is the most common way
  install scripts waste time.
- **Per-stage timing, summary table at completion** — also how a stage that has
  quietly become slow gets noticed.

gum was considered and rejected: it cannot help stage 00 since it is not yet
installed, its strength is interactive prompts that a non-interactive bootstrap
should not have, and reintroducing an omarchy-adjacent dependency into the
omarchy-free installer is self-defeating.

## Verification

Five tiered checks, all scriptable over SSH:

1. `grep -rn omarchy ~/.config/hypr ~/.config/quickshell ~/.local/bin` returns empty
2. Hyprland starts; `hyprctl monitors` responds
3. `qs -c ii` runs without QML errors — logs are block-buffered, so capture via
   `stdbuf -oL` or read the file after exit
4. matugen outputs exist and are non-empty: `colors.json`, `colors-ii.conf`,
   `hyprlock/colors.conf`, kitty colors
5. Screenshot shows the bar rendered (`grim`, roughly 2.4s)

Check 1 encodes the literal project goal as a machine-checkable regression guard.

## Risks

| Risk | Mitigation |
|---|---|
| virgl unreliable on the NVIDIA host | `WLR_RENDERER_ALLOW_SOFTWARE=1` fallback; costs speed, not validity |
| ii meta-package build time | the `deps` snapshot |
| hyprlock variable mismatch | confirmed; budgeted as a rewrite, not a redirect |
| Further untracked local state | Phase 0 audit script |
| Missing fonts | hyprlock wants *Google Sans Flex Medium* and *CaskaydiaMono Nerd Font*; if these miss the package lists the lock screen renders wrong in a way check 5 will not obviously catch |
| matugen output paths absent in the VM | `config.toml` writes to `/etc/chromium/policies/managed/color.json` (root-owned) and a hardcoded Zen profile directory, `rrc9mbf1.Default (release)`, that will not exist on a fresh machine. Stage 30 may fail or partially fail. Resolve by making per-app template blocks conditional on the target app being installed — the same host-versus-VM variance problem B6 solves for hypr, and the clearest case where chezmoi-style templating would have helped |

## Follow-ups

- The recorded decision that omarchy's theme is the single source of truth for
  terminal and desktop colors is superseded by this design once implemented.
  Update it then, not before.
