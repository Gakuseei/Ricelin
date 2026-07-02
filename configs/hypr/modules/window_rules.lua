hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "float-system-dialogs",
    match = { class = "(pavucontrol|nm-connection-editor|blueman-manager|org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk)" },
    float = true,
})

hl.window_rule({
    name  = "float-file-pickers",
    match = { title = "(Open File|Save File|Save As|Choose Files|Open Folder)" },
    float = true,
})

hl.window_rule({
    name  = "float-ghosttype",
    match = { class = "Ghosttype-app" },
    float = true,
})

hl.window_rule({
    name  = "float-spotify",
    match = { class = "[Ss]potify" },
    float = true,
})

hl.window_rule({
    name  = "float-qalculate",
    match = { class = "io.github.Qalculate.qalculate-qt" },
    float = true,
})

hl.window_rule({
    name   = "float-dolphin",
    match  = { class = "org.kde.dolphin" },
    float  = true,
    size   = { 1500, 850 },
    center = true,
})

hl.window_rule({
    name   = "float-vibelark",
    match  = { class = "App", title = "VibeLark" },
    float  = true,
    size   = { 1480, 960 },
    center = true,
})

hl.window_rule({
    name         = "idle-inhibit-fullscreen",
    match        = { class = ".*" },
    idle_inhibit = "fullscreen",
})

local ok, stashApps = pcall(require, "modules.stash-apps")
if ok and type(stashApps) == "table" then
    for _, cls in ipairs(stashApps) do
        hl.window_rule({
            name      = "stash-" .. cls,
            match     = { class = cls },
            workspace = "special:stash",
        })
    end
end
