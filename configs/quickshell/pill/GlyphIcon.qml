import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Vector glyph from baked 24x24 SVG path data, centred by its real bounding box so differing glyphs share one optical baseline.
 */
Item {
    id: root

    property string name: ""
    property color color: Theme.iconDim
    property real stroke: 1.8

    readonly property real u: Math.min(width, height) / 24

    readonly property var glyphs: ({
        "sun": { d: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0m-5 0h1m8-9v1m8 8h1m-9 8v1M5.6 5.6l.7.7m12.1-.7l-.7.7m0 11.4l.7.7m-12.1-.7l-.7.7", fill: false },
        "moon": { d: "M12 3h.393a7.5 7.5 0 0 0 7.92 12.446A9 9 0 1 1 12 2.992z", fill: false },
        "cloud": { d: "M6.657 18C4.085 18 2 15.993 2 13.517s2.085-4.482 4.657-4.482c.393-1.762 1.794-3.2 3.675-3.773c1.88-.572 3.956-.193 5.444 1c1.488 1.19 2.162 3.007 1.77 4.769h.99c1.913 0 3.464 1.56 3.464 3.486s-1.551 3.487-3.465 3.487H6.657", fill: false },
        "cloud-rain": { d: "M7 18a4.6 4.4 0 0 1 0-9a5 4.5 0 0 1 11 2h1a3.5 3.5 0 0 1 0 7m-8-5v2m0 3v2m4-5v2m0 3v2", fill: false },
        "cloud-snow": { d: "M7 18a4.6 4.4 0 0 1 0-9a5 4.5 0 0 1 11 2h1a3.5 3.5 0 0 1 0 7m-8-3v.01m0 3v.01m0 3v.01m4-4v.01m0 3v.01", fill: false },
        "cloud-lightning": { d: "M7 18a4.6 4.4 0 0 1 0-9a5 4.5 0 0 1 11 2h1a3.5 3.5 0 0 1 0 7h-1 M13 14l-2 4h3l-2 4", fill: false },
        "cloud-fog": { d: "M7 16a4.6 4.4 0 0 1 0-9a5 4.5 0 0 1 11 2h1a3.5 3.5 0 0 1 0 7zm-2 4h14", fill: false },
        "droplet": { d: "M7.502 19.423c2.602 2.105 6.395 2.105 8.996 0s3.262-5.708 1.566-8.546l-4.89-7.26c-.42-.625-1.287-.803-1.936-.397a1.4 1.4 0 0 0-.41.397l-4.893 7.26C4.24 13.715 4.9 17.318 7.502 19.423", fill: false },
        "check": { d: "M5 12l5 5L20 7", fill: false },
        "arrow-up": { d: "M12 5v14m6-8l-6-6m-6 6l6-6", fill: false },
        "stopwatch": { d: "M5 13a7 7 0 1 0 14 0a7 7 0 0 0-14 0m9.5-2.5L12 13m5-5l1-1m-4-4h-4", fill: false },
        "type": { d: "M6 4h12m-6 0v16", fill: false },
        "language": { d: "M9 6.371C9 10.789 6.761 13 4 13m0-6.629h7 M5 9c0 2.144 2.252 3.908 6 4m1 7l4-9l4 9m-.9-2h-6.2M6.694 3l.793.582", fill: false },
        "palette": { d: "M12 21a9 9 0 0 1 0-18c4.97 0 9 3.582 9 8c0 1.06-.474 2.078-1.318 2.828S17.693 15 16.5 15H14a2 2 0 0 0-1 3.75A1.3 1.3 0 0 1 12 21 M7.5 10.5a1 1 0 1 0 2 0a1 1 0 1 0-2 0m4-3a1 1 0 1 0 2 0a1 1 0 1 0-2 0m4 3a1 1 0 1 0 2 0a1 1 0 1 0-2 0", fill: false },
        "scaling": { d: "M5 12h14M3 7V5a2 2 0 0 1 2-2h2M3 17v2a2 2 0 0 0 2 2h2M17 3h2a2 2 0 0 1 2 2v2m-4 14h2a2 2 0 0 0 2-2v-2", fill: false },
        "waves": { d: "M3 7q4.5-3 9 0c4.5 3 6 2 9 0M3 17q4.5-3 9 0c4.5 3 6 2 9 0M3 12q4.5-3 9 0c4.5 3 6 2 9 0", fill: false },
        "sparkles": { d: "M16 18a2 2 0 0 1 2 2a2 2 0 0 1 2-2a2 2 0 0 1-2-2a2 2 0 0 1-2 2m0-12a2 2 0 0 1 2 2a2 2 0 0 1 2-2a2 2 0 0 1-2-2a2 2 0 0 1-2 2M9 18a6 6 0 0 1 6-6a6 6 0 0 1-6-6a6 6 0 0 1-6 6a6 6 0 0 1 6 6", fill: false },
        "app-window": { d: "M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zm3 1h.01M9 8h.01", fill: false },
        "layers": { d: "M12 4L4 8l8 4l8-4zm-8 8l8 4l8-4M4 16l8 4l8-4", fill: false },
        "mouse": { d: "M6 7a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v10a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4zm6 0v4", fill: false },
        "keyboard": { d: "M2 8a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2zm4 2v.01m4-.01v.01m4-.01v.01m4-.01v.01M6 14v.01M18 14v.01M10 14l4 .01", fill: false },
        "download": { d: "M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2M7 11l5 5l5-5m-5-7v12", fill: false },
        "minimize": { d: "M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zm0 9h16", fill: false },
        "monitor": { d: "M3 5a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zm4 15h10m-8-4v4m6-4v4m-6-8V8m3 4v-1m3 1v-2m-3 2v-1", fill: false },
        "speaker": { d: "M15 8a5 5 0 0 1 0 8m2.7-11a9 9 0 0 1 0 14M6 15H4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1h2l3.5-4.5A.8.8 0 0 1 11 5v14a.8.8 0 0 1-1.5.5z", fill: false },
        "speaker-off": { d: "M6 15H4a1 1 0 0 1-1-1v-4a1 1 0 0 1 1-1h2l3.5-4.5A.8.8 0 0 1 11 5v14a.8.8 0 0 1-1.5.5zm10-5l4 4m0-4l-4 4", fill: false },
        "mic": { d: "M9 5a3 3 0 0 1 3-3a3 3 0 0 1 3 3v5a3 3 0 0 1-3 3a3 3 0 0 1-3-3z M5 10a7 7 0 0 0 14 0M8 21h8m-4-4v4", fill: false },
        "mic-off": { d: "M3 3l18 18M9 5a3 3 0 0 1 6 0v5a3 3 0 0 1-.13.874m-2 2A3 3 0 0 1 9 10.002v-1 M5 10a7 7 0 0 0 10.846 5.85m2-2A6.97 6.97 0 0 0 18.998 10M8 21h8m-4-4v4", fill: false },
        "lock": { d: "M5 13a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z M11 16a1 1 0 1 0 2 0a1 1 0 0 0-2 0m-3-5V7a4 4 0 1 1 8 0v4", fill: false },
        "lock-outline": { d: "M5 13a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z M8 11V7a4 4 0 1 1 8 0v4", fill: false },
        "logout": { d: "M14 8V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h7a2 2 0 0 0 2-2v-2 M9 12h12l-3-3m0 6l3-3", fill: false },
        "suspend": { d: "M4 12h6l-6 8h6m4-16h6l-6 8h6", fill: false },
        "reboot": { d: "M19.933 13.041a8 8 0 1 1-9.925-8.788c3.899-1 7.935 1.007 9.425 4.747 M20 4v5h-5", fill: false },
        "undo": { d: "M9 14l-4-4l4-4 M5 10h11a4 4 0 1 1 0 8h-1", fill: false },
        "shutdown": { d: "M7 6a7.75 7.75 0 1 0 10 0m-5-2v8", fill: false },
        "mixer": { d: "M4 10a2 2 0 1 0 4 0a2 2 0 0 0-4 0m2-6v4m0 4v8m4-4a2 2 0 1 0 4 0a2 2 0 0 0-4 0m2-12v10m0 4v2m4-13a2 2 0 1 0 4 0a2 2 0 0 0-4 0m2-3v1m0 4v11", fill: false },
        "music": { d: "M3 17a3 3 0 1 0 6 0a3 3 0 0 0-6 0m10 0a3 3 0 1 0 6 0a3 3 0 0 0-6 0 M9 17V4h10v13M9 8h10", fill: false },
        "play": { d: "M6 4v16a1 1 0 0 0 1.524.852l13-8a1 1 0 0 0 0-1.704l-13-8A1 1 0 0 0 6 4", fill: true },
        "pause": { d: "M9 4H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2m8 0h-2a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2", fill: true },
        "next": { d: "M3 5v14a1 1 0 0 0 1.504.864l12-7a1 1 0 0 0 0-1.728l-12-7A1 1 0 0 0 3 5m17-1a1 1 0 0 1 .993.883L21 5v14a1 1 0 0 1-1.993.117L19 19V5a1 1 0 0 1 1-1", fill: true },
        "prev": { d: "M19.496 4.136l-12 7a1 1 0 0 0 0 1.728l12 7A1 1 0 0 0 21 19V5a1 1 0 0 0-1.504-.864M4 4a1 1 0 0 1 .993.883L5 5v14a1 1 0 0 1-1.993.117L3 19V5a1 1 0 0 1 1-1", fill: true },
        "dnd": { d: "M9.346 5.353Q9.661 5.16 10 5a2 2 0 1 1 4 0a7 7 0 0 1 4 6v3m-1 3H4a4 4 0 0 0 2-3v-3a7 7 0 0 1 1.273-3.707M9 17v1a3 3 0 0 0 6 0v-1M3 3l18 18", fill: false },
        "awake": { d: "M10 12a2 2 0 1 0 4 0a2 2 0 0 0-4 0 M21 12q-3.6 6-9 6t-9-6q3.6-6 9-6t9 6", fill: false },
        "chevron-left": { d: "M15 6l-6 6l6 6", fill: false },
        "chevron-right": { d: "M9 6l6 6l-6 6", fill: false },
        "chevron-down": { d: "M6 9l6 6l6-6", fill: false },
        "chevron-up": { d: "M6 15l6-6l6 6", fill: false },
        "terminal": { d: "M5 7l5 5l-5 5m7 2h7", fill: false },
        "search": { d: "M3 10a7 7 0 1 0 14 0a7 7 0 1 0-14 0m18 11l-6-6", fill: false },
        "close": { d: "M18 6L6 18M6 6l12 12", fill: false },
        "trash": { d: "M4 7h16m-10 4v6m4-6v6M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2l1-12M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3", fill: false },
        "return": { d: "M18 6v6a3 3 0 0 1-3 3H5l4-4m0 8l-4-4", fill: false },
        "wifi": { d: "M12 18h.01m-2.838-2.828a4 4 0 0 1 5.656 0m-8.485-2.829a8 8 0 0 1 11.314 0 M3.515 9.515c4.686-4.687 12.284-4.687 17 0", fill: false },
        "bluetooth": { d: "M7 8l10 8l-5 4V4l5 4l-10 8", fill: false },
        "inbox": { d: "M10 5a2 2 0 1 1 4 0a7 7 0 0 1 4 6v3a4 4 0 0 0 2 3H4a4 4 0 0 0 2-3v-3a7 7 0 0 1 4-6M9 17v1a3 3 0 0 0 6 0v-1", fill: false },
        "bolt": { d: "M13 3v7h6l-8 11v-7H5z", fill: false },
        "hotspot": { d: "M12 12v.01m2.828-2.838a4 4 0 0 1 0 5.656m2.829-8.485a8 8 0 0 1 0 11.314m-8.489-2.829a4 4 0 0 1 0-5.656m-2.831 8.485a8 8 0 0 1 0-11.314", fill: false },
        "cog": { d: "M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 0 0 2.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 0 0 1.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 0 0-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 0 0-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 0 0-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 0 0-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 0 0 1.066-2.573c-.94-1.543.826-3.31 2.37-2.37c1 .608 2.296.07 2.572-1.065 M9 12a3 3 0 1 0 6 0a3 3 0 0 0-6 0", fill: false },
        "clock": { d: "M3 12a9 9 0 1 0 18 0a9 9 0 0 0-18 0 M12 7v5l3 3", fill: false },
        "cursor": { d: "M7.904 17.563a1.2 1.2 0 0 0 2.228.308l2.09-3.093l4.907 4.907a1.067 1.067 0 0 0 1.509 0l1.047-1.047a1.067 1.067 0 0 0 0-1.509l-4.907-4.907l3.113-2.09a1.2 1.2 0 0 0-.309-2.228L4 4z", fill: false },
        "video": { d: "M15 10l4.553-2.276A1 1 0 0 1 21 8.618v6.764a1 1 0 0 1-1.447.894L15 14zM3 8a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z", fill: false },
        "record": { d: "M8 5.072a8 8 0 1 1-3.995 7.213L4 12l.005-.285A8 8 0 0 1 8 5.072", fill: true },
        "gamepad": { d: "M12 5h3.5a5 5 0 0 1 0 10H10l-4.015 4.227a2.3 2.3 0 0 1-3.923-2.035l1.634-8.173A5 5 0 0 1 8.6 5z M14 15l4.07 4.284a2.3 2.3 0 0 0 3.925-2.023l-1.6-8.232M8 9v2m-1-1h2m5 0h2", fill: false }
    })

    readonly property var g: glyphs[name] !== undefined ? glyphs[name] : ({ d: "", fill: false })

    Shape {
        id: glyph

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: glyph.boundingRect.width > 0
           ? root.width / 2 - (glyph.boundingRect.x + glyph.boundingRect.width / 2) * root.u
           : (root.width - 24 * root.u) / 2
        y: glyph.boundingRect.height > 0
           ? root.height / 2 - (glyph.boundingRect.y + glyph.boundingRect.height / 2) * root.u
           : (root.height - 24 * root.u) / 2
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.g.fill ? "transparent" : root.color
            fillColor: root.g.fill ? root.color : "transparent"
            strokeWidth: root.stroke * Flags.iconWeight
            fillRule: ShapePath.WindingFill
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.d }
        }
    }
}
