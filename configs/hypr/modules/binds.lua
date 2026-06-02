local mod = "SUPER"

hl.bind(mod .. " + W",         hl.dsp.window.kill())
hl.bind("CTRL + SHIFT + W",    hl.dsp.window.close())
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M",         hl.dsp.window.move({ workspace = "special:minimized", follow = false }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + Left",       hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + Right",      hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))

hl.bind(mod .. " + SHIFT + C",  hl.dsp.exec_cmd("hyprpicker -a"))

hl.bind(mod .. " + Space",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/launcher.sh"))
hl.bind(mod .. " + V",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/clipboard.sh"))

hl.bind(mod .. " + SUPER_L",    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/sidebar.sh"), { release = true })

hl.bind(mod .. " + B",          hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh"))
