-- Personal keybinding overrides. Loaded after Omarchy's defaults, so anything
-- that replaces a default has to unbind it first.
--
-- Ported from the pre-4.0 bindings.conf. Bindings that merely restated an
-- Omarchy default were dropped rather than carried over -- SUPER+RETURN among
-- them, since omarchy-launch-terminal already runs
-- --dir="$(omarchy-cmd-terminal-cwd)" itself.
--
-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Apps on keys Omarchy 4.0 leaves free.
o.bind("SUPER + E", "Yazi", { tui = "yazi" })
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + ALT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + Z", "Zen Browser", { launch = "zen-browser" })
o.bind("SUPER + A", "Claude", { webapp = "https://claude.ai" })
o.bind("SUPER + SHIFT + T", "Teams", { webapp = "https://cloud.teams.microsoft/", focus = true })

-- Replacements for an Omarchy default.
hl.unbind("SUPER + SHIFT + W") -- was Omawrite
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

hl.unbind("SUPER + SHIFT + A") -- was ChatGPT
o.bind("SUPER + SHIFT + A", "Claude", { webapp = "https://claude.ai" })

hl.unbind("SUPER + S") -- was Toggle scratchpad
o.bind("SUPER + S", "Launch apps", "omarchy-menu toggle apps")

hl.unbind("SUPER + L") -- was Toggle workspace layout
o.bind("SUPER + L", "Lock", "omarchy-system-lock")

-- wtfsnip is a native Rust region selector: region -> clipboard PNG + auto-save.
-- Omarchy's own capture bindings are left alone -- ALT+PRINT screenrecording,
-- SUPER+PRINT color picker, SUPER+CTRL+PRINT OCR, SUPER+CTRL+C capture menu.
hl.unbind("PRINT") -- was omarchy-capture-screenshot
o.bind("PRINT", "Screenshot region (wtfsnip)", "wtfsnip")

-- walker is gone in 4.0; these are its replacements. xkbcommon names the keysym
-- "period" in lower case, matching the "comma" bindings in Omarchy's defaults.
o.bind("SUPER + period", "Symbols", "omarchy-shell shell toggle omarchy.emojis")

-- Dropped in the 4.0 port, recorded so the absence reads as deliberate:
--
--   * The volume block (XF86Audio* unbind/rebind through wpctl). It existed
--     only to stop swayosd and the ii shell drawing two OSDs at once. swayosd
--     is no longer installed and omarchy-audio-output-volume draws the shell's
--     own OSD, so the defaults are now correct.
--   * Both wallpaper-selector bindings (SUPER+CTRL+D, SUPER+CTRL+W), which
--     called the ii shell over IPC. 4.0 puts the Background switcher on
--     SUPER+CTRL+SPACE and uses those two keys for Display and Network.
--   * The unbind of SUPER+F, left over from when yazi lived there before moving
--     to SUPER+E. It is Full screen again.
