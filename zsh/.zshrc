# Iris Autocomplete — writes to the terminal, so it must stay above the
# Powerlevel10k instant prompt block.
eval "$(iris init zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_BIN_HOME="$HOME/.local/bin"

export DOTNET_ROOT="$HOME/.dotnet"
# Order matters: this is the de-duplicated result of the four overlapping PATH
# assignments this file used to build up, kept as-is so nothing is shadowed
# differently than before.
export PATH="$HOME/.local/bin:$DOTNET_ROOT/tools:$DOTNET_ROOT:$HOME/bin:/usr/local/bin:$PATH"

# Root scanned by the Ctrl+P project picker
export PROJECT_ROOT="$HOME/source/repos"

# ---------------------------------------------------------------------------
# Shell options
# ---------------------------------------------------------------------------
setopt globdots
setopt ignoreeof
unsetopt BEEP

# Directory stack, used by the Alt+Arrow navigation widgets below
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump/.zcompdump"

source $ZSH/oh-my-zsh.sh

# Tokyo Night syntax highlighting theme
source ~/.oh-my-zsh/custom/themes/tokyo-night/tokyonight_night-zsh-syntax-highlighting.zsh

source ~/.zsh_profile

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.zsh_bw_completion ] && source ~/.zsh_bw_completion

# FZF look & feel — framed panels, colors follow the active omarchy theme.
# Must come before the widget files below: they use its _fzf_footer helper and
# FZF_PREVIEW_* variables.
[ -f ~/.zsh_fzf_theme ] && source ~/.zsh_fzf_theme

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Contrast fixes for the segment colors above, kept separate so that rerunning
# `p10k configure` cannot silently undo them. Must stay after the line above:
# ~/.p10k.zsh begins by unsetting every POWERLEVEL9K_* parameter.
[[ ! -f ~/.p10k-colors.zsh ]] || source ~/.p10k-colors.zsh

# ---------------------------------------------------------------------------
# ZLE widgets
# ---------------------------------------------------------------------------
# Password-manager fuzzy search (Ctrl+B) — see ~/.zsh_pw_search
[ -f ~/.zsh_pw_search ] && source ~/.zsh_pw_search

# fzf pickers (Ctrl+F/H/D/P), Alt+Arrow directory navigation, the Iris
# suspend/resume wrapper and the Ctrl+å Claude launcher — see ~/.zsh_widgets.
# Sourced after .zsh_pw_search so the Iris wrapper can catch its widget too.
[ -f ~/.zsh_widgets ] && source ~/.zsh_widgets

# zoxide
eval "$(zoxide init --cmd cd zsh)"
