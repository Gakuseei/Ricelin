local mod = "SUPER"

hl.bind(mod .. " + W",         hl.dsp.window.kill())
hl.bind("CTRL + SHIFT + W",    hl.dsp.window.close())
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M",         hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/minimize-toggle.sh"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Left",       hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + Right",      hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

hl.bind(mod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1,  follow = false }))
hl.bind(mod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2,  follow = false }))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3,  follow = false }))
hl.bind(mod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4,  follow = false }))
hl.bind(mod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5,  follow = false }))
hl.bind(mod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6,  follow = false }))
hl.bind(mod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7,  follow = false }))
hl.bind(mod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8,  follow = false }))
hl.bind(mod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9,  follow = false }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = false }))

hl.bind(mod .. " + P",         hl.dsp.workspace.toggle_special("private"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-toggle.sh private"))

hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("stash"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/special-toggle.sh stash"))

hl.bind(mod .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"))

hl.bind(mod .. " + Space",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh launcher"))
hl.bind(mod .. " + V",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh clipboard"))

hl.bind(mod .. " + L",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/lock.sh"))

hl.bind(mod .. " + B",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh"))
hl.bind(mod .. " + C",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh wallpaper"))
hl.bind(mod .. " + D",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/record.sh"))
hl.bind(mod .. " + G",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-surface.sh gameMode"))

-- One key summons the Boombox visualizer and the same key sends it away.
-- Where it lives: RICELIN_BOOMBOX_QML (see scripts/qs-toggle.sh).
hl.bind(mod .. " + Z",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/qs-toggle.sh boombox")) -- Boombox
-- Persona is a style, like any other setup in ~/.config/quickshell. The same
-- switch lives in the pill's palette button; see scripts/ricelin-style.
hl.bind(mod .. " + SHIFT + Z",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/ricelin-style toggle persona")) -- Persona style

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",        hl.dsp.global("quickshell:mediaToggle"),                           { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.global("quickshell:mediaNext"),                             { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.global("quickshell:mediaPrev"),                             { locked = true })
hl.bind("ALT + M", hl.dsp.exec_cmd("simulide")) -- SimulIDE
