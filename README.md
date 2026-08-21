# Dotfiles

Personal configuration, managed with GNU Stow. Each top-level directory
is a stow package whose contents mirror the layout under `$HOME`.

| Package | Contents |
|---|---|
| `bash/` | `.bashrc`, `.bash_profile`, `.profile`, `.bash_logout` |
| `zsh/` | `.zshrc`, `.zsh_alias`, `.zsh_profile`, powerlevel10k theme, fzf/bitwarden helpers |
| `nvim/` | LazyVim config (`.config/nvim`), including `lazy-lock.json` |
| `kitty/` | `kitty.conf` |
| `matugen/` | matugen config + the templates that fan the wallpaper palette out to Chromium, Hyprland, kitty, iris, ncspot and Zen |
| `hypr/` | Hyprland config that is *not* coupled to Omarchy: `hyprlock.conf`, `hyprsunset.conf`, `xdph.conf` |
| `omarchy/` | Omarchy-coupled config: the Hyprland `.lua` files, `shell.json`, the lock plugin, and `~/.local/bin` wrappers that shadow Omarchy commands |

`docs/` is **not** a package — it holds design specs and implementation
plans, and must never be stowed.

## Usage

Install everything:

```bash
cd ~/dotfiles
stow bash zsh nvim kitty matugen hypr omarchy
```

Note the explicit package list. Do **not** use `stow */` — it would treat
`docs/` as a package and litter `$HOME` with a `superpowers` symlink.

Install, remove, or refresh a single package:

```bash
stow zsh        # install
stow -D zsh     # remove
stow -R zsh     # refresh, e.g. after adding files to the package
```

## Setup on a new machine

```bash
git clone https://github.com/timvi402/dotfiles ~/dotfiles
cd ~/dotfiles
stow bash zsh nvim kitty matugen hypr omarchy
```

`omarchy/system/` mirrors root-owned files that live outside `$HOME`;
stow skips it, and `omarchy/system/README.md` explains how to install
them by hand.

## Adding new config to a package

Stow links, it does not copy, so move the real file into the package and
let stow put the symlink back:

```bash
mv ~/.config/app/config.toml ~/dotfiles/app/.config/app/config.toml
cd ~/dotfiles && stow -R app
git add app && git commit
```

Verify a file is genuinely linked rather than a stale copy — note that a
*folded* package shows up as a symlinked parent directory, so testing the
file itself for `-L` is not enough:

```bash
readlink -f ~/.config/app/config.toml   # must land inside ~/dotfiles
```

## Generated files

Some paths under a stowed package are written by other tools and are
deliberately gitignored — `kitty/.config/kitty/colors-matugen.conf` (matugen
writes the palette) and `nvim/.config/nvim/lua/plugins/theme.lua` (Omarchy
symlinks the active theme). Leave both to their owners.
