require("modules.env")
require("modules.monitors")
require("modules.input")
require("modules.decoration")
require("modules.animations")
require("modules.binds")
require("rishot")
require("modules.window_rules")
require("modules.autostart")

pcall(require, "modules.private")

-- GhostType hotkey (managed by the app)
pcall(require, "ghosttype")
