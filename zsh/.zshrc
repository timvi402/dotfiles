# Iris Autocomplete
eval "$(iris init zsh)"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH. 
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder


# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Environment variables
export DOTNET_ROOT=$HOME/.dotnet
export PATH="$DOTNET_ROOT:$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/.dotnet/tools"


# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

setopt globdots 
setopt ignoreeof
unsetopt BEEP


export ZSH="$HOME/.oh-my-zsh"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_BIN_HOME="$HOME/.local/bin"
export PATH=$HOME/.local/bin:$HOME/.dotnet/tools:$PATH
ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump/.zcomdump"



# plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-autocomplete)

source $ZSH/oh-my-zsh.sh

# Tokyo Night syntax highlighting theme
source ~/.oh-my-zsh/custom/themes/tokyo-night/tokyonight_night-zsh-syntax-highlighting.zsh

source ~/.zsh_profile
autoload -U compinit -d $XDG_CACHE_HOME/zsh/zcompdump/.zcomdump



# To customize prompt, run `p10k configure` or edit ~/.zsh/.p10k.zsh.
# [[ ! -f ~/.zsh/.p10k.zsh ]] || source ~/.zsh/.p10k.zsh
 
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.zsh_bw_completion ] && source ~/.zsh_bw_completion

# FZF look & feel — framed panels, colors follow the active omarchy theme
[ -f ~/.zsh_fzf_theme ] && source ~/.zsh_fzf_theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Contrast fixes for the segment colors above, kept separate so that rerunning
# `p10k configure` cannot silently undo them. Must stay after the line above:
# ~/.p10k.zsh begins by unsetting every POWERLEVEL9K_* parameter.
[[ ! -f ~/.p10k-colors.zsh ]] || source ~/.p10k-colors.zsh


# Redraw prompt after changing directory inside a ZLE widget
# Pattern taken from fzf's own integration.
__redraw_prompt() {
  local precmd
  for precmd in $precmd_functions; do
    $precmd           # run all precmd hooks (Powerlevel10k updates here)
  done
  zle .reset-prompt   # recompute prompt
  zle -R              # repaint
}



# Ctrl+F fuzzy file finder
__fzf_file_finder() {
  local selected
  selected=$(
    fd --type f --hidden --exclude .git 2>/dev/null |
    fzf --input-label='  files ' \
        --list-label=" ${PWD/#$HOME/~} " \
        --preview="$FZF_PREVIEW_FILE" \
        --preview-label='  preview ' \
        --footer="$(_fzf_footer enter 'open in nvim' ctrl-/ 'toggle preview')" \
        2>/dev/null
  )
  if [[ -n "$selected" ]]; then
    nvim "$selected"
    zle .reset-prompt
  fi
}

# Create zle widget and bind Ctrl+F
zle -N __fzf_file_finder
bindkey '^F' __fzf_file_finder


# Ctrl+H fuzzy history search
__fzf_history_search() {
  local selected
  selected=$(
    fc -rl 1 | awk '{$1=""; print substr($0,2)}' |
    fzf --input-label='  history ' \
        --list-label=' commands ' \
        --tac --no-sort --exact \
        --preview='echo {}' \
        --preview-window='down,3,wrap' \
        --preview-label=' full command ' \
        --footer="$(_fzf_footer enter 'put on command line' esc 'cancel')" \
        2>/dev/null
  )
  if [[ -n "$selected" ]]; then
    BUFFER="$selected"
    CURSOR=$#BUFFER
    zle redisplay
  fi
}

zle -N __fzf_history_search
bindkey '^H' __fzf_history_search



__fzf_dir_finder() {
  local selected

  selected=$(
    fd --type d --hidden --exclude .git 2>/dev/null |
    fzf --input-label='  directories ' \
        --list-label=" ${PWD/#$HOME/~} " \
        --preview="$FZF_PREVIEW_DIR" \
        --preview-label='  contents ' \
        --footer="$(_fzf_footer enter 'cd into directory' ctrl-/ 'toggle preview')"
  ) || { zle redisplay; return }

  [[ -n $selected ]] || { zle redisplay; return }

  # Change directory quietly
  builtin cd -- "$selected" 2>/dev/null || { zle redisplay; return }

  # Clean up and redraw the prompt (including P10k path segment)
  zle -I
  __redraw_prompt
}

zle -N __fzf_dir_finder
bindkey '^D' __fzf_dir_finder


export PROJECT_ROOT="$HOME/source/repos"

_fuzzy_project_cd() {
  local selection display_path
  selection=$(
    {
      command find "$PROJECT_ROOT" \
        -mindepth 1 -maxdepth 3 \
        -type d -name .git -prune 2>/dev/null \
      | sed 's|/\.git$||'
    } | sort -u | sed "s|^$PROJECT_ROOT/||" |
    fzf --input-label='  projects ' \
        --list-label=" ${PROJECT_ROOT/#$HOME/~} " \
        --preview='cd "$PROJECT_ROOT"/{} 2>/dev/null && {
                     timeout 2 git -c color.ui=always log --oneline --decorate -n 8 2>/dev/null && echo;
                     timeout 2 eza -a --icons=always --color=always --group-directories-first 2>/dev/null || ls -A;
                   }' \
        --preview-label='  recent commits ' \
        --footer="$(_fzf_footer enter 'cd into project' ctrl-/ 'toggle preview')"
  ) || { zle redisplay; return }

  [[ -n $selection ]] || { zle redisplay; return }

  # Reconstruct full path for cd
  builtin cd -- "$PROJECT_ROOT/$selection" 2>/dev/null || { zle redisplay; return }

  zle -I
  __redraw_prompt

}

zle -N _fuzzy_project_cd
bindkey '^P' _fuzzy_project_cd



setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Browser-like navigation: forward stack for Alt+Right
typeset -g -a _dir_forward_stack

# Clear forward stack when changing directory normally
_clear_forward_stack() {
  _dir_forward_stack=()
}
chpwd_functions+=(_clear_forward_stack)

_dir_back() {
  if ! builtin popd -q 2>/dev/null; then
    # Empty stack or error – stay silent
    zle -I
    zle redisplay
    return 0
  fi

  # Save the directory we just left to forward stack
  _dir_forward_stack+=("$OLDPWD")

  zle -I
  __redraw_prompt
}

_dir_forward() {
  # Only allow forward if we have entries in the forward stack
  if [[ ${#_dir_forward_stack[@]} -eq 0 ]]; then
    zle -I
    zle redisplay
    return 0
  fi

  # Get the last directory from forward stack
  local target="${_dir_forward_stack[-1]}"
  _dir_forward_stack[-1]=()

  # Push current dir and change to target
  builtin pushd -q "$target" 2>/dev/null || {
    zle -I
    zle redisplay
    return 0
  }

  zle -I
  __redraw_prompt
}

zle -N _dir_back
zle -N _dir_forward
bindkey '^[[1;3D' _dir_back     # Alt+ArrowLeft (browser-style)
bindkey '^[[1;3C' _dir_forward  # Alt+ArrowRight (browser-style)

# Password-manager fuzzy search (Ctrl+B) — see ~/.zsh_pw_search
[ -f ~/.zsh_pw_search ] && source ~/.zsh_pw_search


# Keep Iris' suggestion overlay out of the fzf pickers.
#
# Iris (the autocomplete wrapper eval'd at the top of this file) learns that the
# terminal is busy from the preexec/precmd hooks it installs — but a ZLE widget
# never fires either one, so from Iris' point of view we are still sitting at the
# prompt and it happily paints suggestions on top of a full-screen fzf.
#
# The fix is to hand Iris the same markers its own hooks send, around the widget.
# Both are NUL-terminated writes to $IRIS_FD, the descriptor `iris init zsh`
# exports; when Iris isn't running the variable is unset and these are no-ops, so
# the config still works in a plain shell (or under IRIS_RESCUE=1).
_iris_suspend() { [[ -n $IRIS_FD ]] && print -u $IRIS_FD -N -r -- "IRIS_CMD_START" 2>/dev/null }
_iris_resume()  { [[ -n $IRIS_FD ]] && print -u $IRIS_FD -N -r -- "IRIS_CMD_STOP:0" 2>/dev/null }

# One wrapper serves every picker: ZLE sets $WIDGET to the name of the widget
# being run, and each of these widgets was registered under the same name as its
# function — so "$WIDGET" calls the original body. Registering the wrapper with
# `zle -N <name> _iris_quiet_widget` leaves that function untouched.
_iris_quiet_widget() {
  _iris_suspend
  "$WIDGET" "$@"
  local ret=$?
  _iris_resume
  return $ret
}

# Re-register the screen-grabbing widgets through the wrapper. Guarded on the
# function existing, since ~/.zsh_pw_search is sourced conditionally above.
for _iris_w in __fzf_file_finder __fzf_dir_finder __fzf_history_search \
               _fuzzy_project_cd __fzf_pw_search; do
  (( $+functions[$_iris_w] )) && zle -N $_iris_w _iris_quiet_widget
done
unset _iris_w


# Launch Claude Code with Ctrl+å (kitty maps it to the CSI-u sequence \e[229;5u)
__launch_claude() {
  BUFFER="claude"
  zle accept-line
}
zle -N __launch_claude
bindkey '^[[229;5u' __launch_claude


# zoxide
eval "$(zoxide init --cmd cd zsh)"
