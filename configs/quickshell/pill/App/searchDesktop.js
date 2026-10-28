.pragma library

/** Search rows for the windows, workspaces, animation, display and input pages, shaped like searchIndex.js entries. */
var entries = [
    { page: "windows", tab: "", group: "Windows", label: "Inner gaps", sub: "Space between tiled windows", keywords: "gaps gap spacing padding tiling between windows", key: "windows.gapsIn", advanced: false },
    { page: "windows", tab: "", group: "Windows", label: "Outer gaps", sub: "Space between windows and the screen edge", keywords: "gaps gap margin edge border spacing", key: "windows.gapsOut", advanced: false },
    { page: "windows", tab: "", group: "Windows", label: "Rounding", sub: "How round window corners are", keywords: "corners corner radius round rounded", key: "windows.rounding", advanced: false },
    { page: "windows", tab: "", group: "Windows", label: "Border size", sub: "Thickness of the coloured window outline", keywords: "border outline frame thickness width", key: "windows.borderSize", advanced: true },
    { page: "windows", tab: "", group: "Windows", label: "Layout", sub: "How new windows split the screen", keywords: "tiling dwindle master split layout", key: "windows.layout", advanced: false },
    { page: "windows", tab: "", group: "Windows", label: "Rounding power", sub: "Higher bends corners toward a squircle", keywords: "squircle corners curvature smooth", key: "windows.roundingPower", advanced: true },
    { page: "windows", tab: "", group: "Windows", label: "Resize on border", sub: "Drag a window edge to resize it", keywords: "resize drag edge mouse", key: "windows.resizeOnBorder", advanced: true },
    { page: "windows", tab: "", group: "Shadow", label: "Shadow", sub: "Soft shadow under every window", keywords: "drop shadow depth", key: "windows.shadow", advanced: false },
    { page: "windows", tab: "", group: "Shadow", label: "Shadow range", sub: "How far the shadow spreads", keywords: "shadow size spread", key: "windows.shadowRange", advanced: true },
    { page: "windows", tab: "", group: "Shadow", label: "Shadow render power", sub: "Higher gives the shadow a harder edge", keywords: "shadow falloff sharpness edge", key: "windows.shadowPower", advanced: true },
    { page: "windows", tab: "", group: "Blur", label: "Blur", sub: "Frost what shows through see-through windows", keywords: "frosted glass transparency transparent background", key: "windows.blur", advanced: false },
    { page: "windows", tab: "", group: "Blur", label: "Blur size", sub: "How strong the blur is", keywords: "blur strength radius frosted", key: "windows.blurSize", advanced: false },
    { page: "windows", tab: "", group: "Blur", label: "Blur passes", sub: "More passes look smoother but cost more", keywords: "blur quality smooth performance", key: "windows.blurPasses", advanced: true },
    { page: "windows", tab: "", group: "Blur", label: "Blur vibrancy", sub: "How much colour survives behind the blur", keywords: "blur saturation colour color vibrant", key: "windows.blurVibrancy", advanced: true },
    { page: "windows", tab: "", group: "Blur", label: "Blur noise", sub: "Fine grain mixed into the blur", keywords: "blur grain noise texture", key: "windows.blurNoise", advanced: true },
    { page: "windows", tab: "", group: "Opacity", label: "Active window opacity", sub: "How solid the window you work in is", keywords: "opacity transparency transparent see-through focused alpha", key: "windows.opacityActive", advanced: false },
    { page: "windows", tab: "", group: "Opacity", label: "Inactive window opacity", sub: "How solid every other window is", keywords: "opacity transparency transparent see-through unfocused dim alpha", key: "windows.opacityInactive", advanced: false },
    { page: "windows", tab: "", group: "Night light", label: "Night light", sub: "Warms the screen colours to ease your eyes", keywords: "night light blue light filter warm hyprsunset evening eyes", key: "windows.nightMode", advanced: false },
    { page: "windows", tab: "", group: "Night light", label: "Night light temperature", sub: "Lower is warmer", keywords: "kelvin warm temperature colour color night", key: "windows.nightTemp", advanced: false },
    { page: "windows", tab: "", group: "Night light", label: "Night light on at", sub: "When the warm tint starts", keywords: "schedule evening start time night", key: "windows.nightOn", advanced: false },
    { page: "windows", tab: "", group: "Night light", label: "Night light off at", sub: "When colours go back to normal", keywords: "schedule morning end time night", key: "windows.nightOff", advanced: false },

    { page: "workspaces", tab: "", group: "Special spaces", label: "Stash", sub: "Background apps open here", keywords: "special space scratchpad background super s", key: "workspaces.stash", advanced: false },
    { page: "workspaces", tab: "", group: "Special spaces", label: "Stash apps", sub: "Apps whose windows open in the stash", keywords: "stash apps route window class background spotify", key: "workspaces.stashApps", advanced: false },
    { page: "workspaces", tab: "", group: "Special spaces", label: "Private space", sub: "A hidden scratchpad", keywords: "special space private hidden scratchpad super p", key: "workspaces.private", advanced: false },
    { page: "workspaces", tab: "", group: "Special spaces", label: "Minimized space", sub: "Minimized windows wait here", keywords: "special space minimize minimized hide super shift m", key: "workspaces.minimized", advanced: false },
    { page: "workspaces", tab: "", group: "Special spaces", label: "New special space", sub: "A name, a Super key and a glyph", keywords: "add create custom special space workspace scratchpad key", key: "workspaces.add", advanced: false },

    { page: "animation", tab: "", group: "Motion", label: "Animations", sub: "Windows, workspaces and fades move instead of jumping", keywords: "animation motion effects off disable", key: "animation.enabled", advanced: false },
    { page: "animation", tab: "", group: "Motion", label: "Animation duration", sub: "How long each move takes. Lower is quicker", keywords: "speed fast slow quick duration time ms", key: "animation.speed", advanced: false },
    { page: "animation", tab: "", group: "Curve", label: "Motion curve", sub: "How a move speeds up and settles", keywords: "easing curve bezier smooth snappy linear preset", key: "animation.curve", advanced: false },
    { page: "animation", tab: "", group: "Curve", label: "Curve editor", sub: "Drag the handles and watch the preview", keywords: "bezier custom easing handles preview play", key: "animation.editor", advanced: false },

    { page: "display", tab: "", group: "Monitors", label: "Monitor arrangement", sub: "Where each screen sits next to the other", keywords: "monitor screen position arrange layout left right above", key: "display.map", advanced: false },
    { page: "display", tab: "", group: "Monitors", label: "Resolution", sub: "Pixels on the selected screen", keywords: "resolution mode size pixels 1080p 1440p 4k", key: "display.resolution", advanced: false },
    { page: "display", tab: "", group: "Monitors", label: "Refresh rate", sub: "Higher is smoother", keywords: "refresh rate hz fps 144 240 smooth", key: "display.refresh", advanced: false },
    { page: "display", tab: "", group: "Monitors", label: "Display scale", sub: "How big everything looks on a screen", keywords: "scale scaling zoom hidpi size dpi", key: "display.scale", advanced: false },
    { page: "display", tab: "", group: "Monitors", label: "Main monitor", sub: "The screen workspace 1 lives on", keywords: "main primary monitor screen workspaces", key: "display.main", advanced: false },

    { page: "input", tab: "", group: "Devices", label: "Connected devices", sub: "Keyboards and mice with their polling rate", keywords: "polling rate hz keyboard mouse usb wireless receiver devices", key: "input.devices", advanced: false },
    { page: "input", tab: "", group: "Pointer", label: "Mouse sensitivity", sub: "How fast the pointer moves", keywords: "mouse pointer speed sensitivity dpi touchpad", key: "input.sensitivity", advanced: false },
    { page: "input", tab: "", group: "Pointer", label: "Mouse acceleration", sub: "Adaptive speeds up quick flicks", keywords: "acceleration accel flat adaptive pointer mouse", key: "input.accel", advanced: false },
    { page: "input", tab: "", group: "Keyboard", label: "Keyboard layout", sub: "Which letters your keys type", keywords: "keyboard layout language qwerty qwertz german english us", key: "input.layout", advanced: false },
    { page: "input", tab: "", group: "Keyboard", label: "Key repeat rate", sub: "Characters per second while a key is held", keywords: "repeat rate keyboard hold typing speed", key: "input.repeatRate", advanced: true },
    { page: "input", tab: "", group: "Keyboard", label: "Key repeat delay", sub: "How long to hold a key before it repeats", keywords: "repeat delay keyboard hold wait", key: "input.repeatDelay", advanced: true },
    { page: "input", tab: "", group: "Keyboard", label: "Numlock on start", sub: "Turn numlock on when you log in", keywords: "numlock num lock numpad keypad", key: "input.numlock", advanced: true },
    { page: "input", tab: "", group: "Cursor", label: "Cursor size", sub: "How big the mouse pointer is", keywords: "cursor pointer size big small mouse", key: "input.cursorSize", advanced: false },
    { page: "input", tab: "", group: "Cursor", label: "Cursor theme", sub: "The look of the mouse pointer", keywords: "cursor pointer theme bibata style look", key: "input.cursorTheme", advanced: false }
];
