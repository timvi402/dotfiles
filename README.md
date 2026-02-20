# Dotfiles

My personal configuration files managed with GNU Stow.

## Structure

Each directory represents a package that can be stowed independently:
- `bash/` - Bash configuration
- `zsh/` - Zsh configuration  
- `git/` - Git configuration
- `nvim/` - Neovim configuration
- `kitty/` - Kitty terminal configuration

## Usage

### Install all dotfiles
```bash
cd ~/dotfiles
stow */
```

### Install specific package
```bash
cd ~/dotfiles
stow zsh
```

### Uninstall package
```bash
cd ~/dotfiles
stow -D zsh
```

### Re-stow (useful after adding new files)
```bash
cd ~/dotfiles
stow -R zsh
```

## Setup on a new machine

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
stow */
```

## Adding new dotfiles

1. Create package directory if needed: `mkdir -p ~/dotfiles/package_name`
2. Move the dotfile: `mv ~/.config/app ~/dotfiles/package_name/.config/`
3. Stow the package: `cd ~/dotfiles && stow package_name`
4. Commit: `git add . && git commit -m "Add app config"`
