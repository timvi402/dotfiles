# Powerlevel10k contrast overrides. Sourced from .zshrc immediately after
# ~/.p10k.zsh, whose values these replace.
#
# Why this file exists
# --------------------
# ~/.p10k.zsh is the wizard-generated rainbow config, and its segment colors
# assume a classic 16-color terminal palette in which ANSI 1/4/5/6 are *dark*
# accents that comfortably carry light text. Since matugen took over kitty's
# palette (see ~/.config/matugen/templates/kitty/colors.conf) those slots hold
# Material You accent tones instead, and in a dark scheme those are deliberately
# *light*: they are built to be foreground on a dark surface, not background
# under white text.
#
# So the rainbow config ends up painting light on light. The directory segment
# renders #e4e4e4 on #95ceed (1.34:1) and a failed command renders yellow on
# salmon (1.18:1) — legible only if you already know what they say.
#
# The rule applied below
# ----------------------
# On an accent-colored chip the text becomes ANSI 0, which the kitty template
# maps to surface_container_high. That makes every such chip a surface/accent
# pair drawn from one generated palette, which is the pairing Material You is
# built to keep legible — measured, the worst of them is 7.2:1 and most are
# ~8.5:1. The fixed 256-color values (232, 250, 254, 255, 240) are replaced for
# a related reason: they are frozen greys that cannot track the palette at all,
# so they only ever look right against one particular wallpaper.
#
# Scope of that guarantee: it holds for the dark palette this machine generates
# (gsettings color-scheme is prefer-dark, so switchwall.sh passes matugen
# --mode dark). It is not a claim about every palette. Under `--mode light` the
# M3 roles all invert together and these pairs stay fine, but color2/color3 do
# not invert with them — they fall through from the Omarchy theme — so a light
# matugen palette under the current dark theme would leave the vcs and
# command_execution_time chips light-on-light. That is the whole terminal's
# problem rather than this file's: kitty's own background would be light while
# the theme's ANSI colors stayed tuned for a dark one.
#
# On a machine where matugen has never run and the raw Tokyo Night palette shows
# through, these values help but do not rescue it: 13 of the 74 enabled pairs
# still land under 4.5:1, against 24 for the stock config. That palette puts
# ANSI 0, 7 and 8 all in the same middle band, so no single foreground index
# separates from all of them.
#
# What is deliberately NOT here
# -----------------------------
# Segments that already put a light accent *on* ANSI 0 rather than under it —
# status ok, background_jobs, context, time, and every asdf/*env chip — are
# correct as written and are left alone. The vcs backgrounds are also untouched:
# green and yellow keep falling through from the Omarchy theme, for the same
# reason the kitty template leaves those two slots undefined. Only the vcs
# *foregrounds* needed fixing, and because they live inside my_git_formatter
# they are patched in ~/.p10k.zsh itself rather than here.
#
# Ordering matters: ~/.p10k.zsh opens by running `unset -m 'POWERLEVEL9K_*'`, so
# this file has to be sourced after it, never before.

() {
  emulate -L zsh -o extended_glob

  # os_icon. 232 is near-black and only worked because on_surface_variant lands
  # light in a dark scheme; under --mode light it inverts and the chip goes
  # black-on-charcoal. ANSI 0 tracks the scheme instead.
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=0

  # dir — the headline fix. All three tiers were frozen greys on the primary
  # accent: 254 (1.34:1), 255 (1.47:1) and 250 (1.11:1). The tiers now separate
  # by weight rather than by lightness, which DIR_ANCHOR_BOLD=true in ~/.p10k.zsh
  # already provides.
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=0
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=0
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=0

  # status, error variants. Yellow text on the error accent was 1.18:1 — the
  # worst pairing in the prompt, and the one that shows up exactly when a command
  # has just failed and you need to read it.
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=0
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=0
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=0

  # Cloud and tool chips. Every one of these had FOREGROUND=7 over an accent
  # background, which is now light-on-light at ~1.0:1. Their working siblings
  # (ASDF_PYTHON, VIRTUALENV, PYENV, …) already use 0 over the same backgrounds,
  # so this just makes the set consistent.
  typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND=0
  typeset -g POWERLEVEL9K_AZURE_OTHER_FOREGROUND=0
  typeset -g POWERLEVEL9K_GCLOUD_FOREGROUND=0
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_FOREGROUND=0
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=0
  typeset -g POWERLEVEL9K_NORDVPN_FOREGROUND=0

  # The mirror image: FOREGROUND=1 over ANSI 7, i.e. a light error tone on a
  # light neutral. Same 1.0:1, same fix.
  typeset -g POWERLEVEL9K_ASDF_JAVA_FOREGROUND=0
  typeset -g POWERLEVEL9K_JENV_FOREGROUND=0

  # timewarrior. 255 on the outline tone was 2.73:1.
  #
  # This and todo (already 0) are the weakest pairs left, at 4.55:1 — just over
  # the 4.5:1 floor. ANSI 8 is `outline`, a mid tone by design, so nothing in the
  # palette contrasts strongly against it; 0 is the best of the options and 15
  # would be worse at 2.56:1. If these ever read as muddy, the fix is to move
  # them onto the neutral chip the other informational segments use —
  # POWERLEVEL9K_{TODO,TIMEWARRIOR}_BACKGROUND=0 with FOREGROUND=7, which
  # measures 8.43:1.
  typeset -g POWERLEVEL9K_TIMEWARRIOR_FOREGROUND=0

  # rvm. Not a matugen problem — 240 is a hardcoded mid-grey in the stock config
  # and has always been 2.02:1 under black text. Moved onto the same background
  # rbenv uses, which keeps the ruby segments looking alike.
  typeset -g POWERLEVEL9K_RVM_BACKGROUND=1

  # Segments not currently in POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_ELEMENTS, carrying
  # the same defect. Set here so that uncommenting one later does not quietly
  # reintroduce an unreadable chip.
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=0
  typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND=0
  typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND=0
  typeset -g POWERLEVEL9K_LARAVEL_VERSION_FOREGROUND=0
  typeset -g POWERLEVEL9K_DOTNET_VERSION_FOREGROUND=0
  typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_FOREGROUND=0
  typeset -g POWERLEVEL9K_EXAMPLE_FOREGROUND=0
}
