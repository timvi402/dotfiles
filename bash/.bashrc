# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# Ctrl+B fuzzy Bitwarden vault search
__fzf_bitwarden_search() {
  local bw_status
  bw_status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null)

  if [[ "$bw_status" == "unauthenticated" ]]; then
    echo "Bitwarden: not logged in. Run 'bw login' first."
    return
  fi

  if [[ "$bw_status" == "locked" ]]; then
    local session_key
    session_key=$(bw unlock --raw)
    if [[ $? -ne 0 || -z "$session_key" ]]; then
      echo "Failed to unlock vault."
      return
    fi
    export BW_SESSION="$session_key"
  fi

  echo -n "  🔐 Fetching vault items…"
  local items
  items=$(bw list items 2>/dev/null \
    | jq -r '.[] | select(.type == 1) | "\(.id)\t\(.name)\t\(.login.username // "")"')
  echo -e "\r\033[K"  # Clear the status line

  local selected
  selected=$(printf '%s\n' "$items" \
    | fzf --prompt="Bitwarden> " --height=40% --reverse \
          --delimiter=$'\t' --with-nth=2,3)

  [[ -z "$selected" ]] && return

  local item_id password
  item_id=$(printf '%s' "$selected" | cut -f1)
  echo -n "  🔑 Getting password…"
  password=$(bw get password "$item_id" 2>/dev/null)
  echo -e "\r\033[K"  # Clear the status line

  if [[ -n "$password" ]]; then
    if command -v wl-copy &>/dev/null; then
      printf '%s' "$password" | wl-copy
    elif command -v xclip &>/dev/null; then
      printf '%s' "$password" | xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
      printf '%s' "$password" | xsel --clipboard
    else
      echo "✗ No clipboard utility found (wl-copy, xclip, xsel)"
      return
    fi
    echo "✓ Password copied to clipboard."
  else
    echo "✗ No password found for selected item."
  fi
}

bind -x '"\C-b": __fzf_bitwarden_search'
