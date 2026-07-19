require("modules.env")
require("modules.monitors")
require("modules.input")
require("modules.decoration")
require("modules.animations")
require("modules.binds")
require("rishot")
require("modules.window_rules")
require("modules.spaces-apply")
require("modules.autostart")

pcall(require, "modules.private")

-- Personal machine-only hooks (gitignored local.lua: discord, crosshair, ...)
pcall(require, "local")

-- GhostType hotkey (managed by the app)
pcall(require, "ghosttype")
