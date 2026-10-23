pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette with the curated washi/flame hex by default, where surfaces and accents follow the wallpaper via Dyn when the dynamic flag is on.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"

    /**
     * The dynamic branch uses Dyn.primary because matugen's on-primary-container does not populate here and collapses the token to black.
     */
    readonly property color onGlow: dyn ? Dyn.primary : "#ff9a64"

    readonly property color verm:     dyn ? Qt.darker(Dyn.primary, 1.18) : "#c0442b"
    readonly property color vermLit:  dyn ? Dyn.primary : "#e0563b"
    readonly property color vermDeep: dyn ? Dyn.primaryContainer : "#a3371f"
    readonly property color cream:    dyn ? Dyn.cream : "#e6d6cb"
    readonly property color bright:   dyn ? Dyn.bright : "#fff6f0"
    readonly property color dim:      dyn ? Dyn.dim : "#8a7d74"
    readonly property color cardTop:  dyn ? Dyn.surfaceContainerHigh : "#2e231b"
    readonly property color cardBot:  dyn ? Dyn.surfaceContainerLow : "#221813"
    readonly property color border:   dyn ? Dyn.outlineVariant : "#3a2a22"
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   dyn ? Dyn.surface : "#211711"
    readonly property color subtle:   dyn ? Dyn.subtle : "#b9a99e"
    readonly property color faint:    dyn ? Dyn.faint : "#6f635b"
    readonly property color iconDim:  dyn ? Dyn.iconDim : "#cdbfb4"
    readonly property color hair:     Qt.alpha(cream, 0.13)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.07)
    readonly property color danger:    "#e0533f"

    /**
     * Readable faint text (4.5:1 on the cards); faint itself stays for strokes and dividers.
     */
    readonly property color textFaint: dyn ? Qt.rgba((Qt.color(Dyn.faint).r + Qt.color(Dyn.subtle).r) / 2, (Qt.color(Dyn.faint).g + Qt.color(Dyn.subtle).g) / 2, (Qt.color(Dyn.faint).b + Qt.color(Dyn.subtle).b) / 2, 1) : "#9a8c82"
    readonly property color accentFill: dyn ? Dyn.primary : "#a3371f"
    readonly property color onAccent:   dyn ? Dyn.surface : "#fff6f0"

    /**
     * The one type, space and corner scale every surface draws from, in unscaled pixels.
     */
    readonly property var fs: ({ label: 9, meta: 10.5, body: 12.5, title: 15, display: 30 })
    readonly property var sp: ({ xxs: 2, xs: 4, s: 8, m: 12, l: 16, xl: 20 })
    readonly property var r: ({ xs: 4, s: 7, m: 9, l: 13, full: 999 })
    readonly property var inset: ({ top: 15, side: 18, bottom: 14 })
    readonly property real labelTracking: 1.4
    readonly property color pressBg: Qt.alpha(cream, 0.09)

    readonly property color vermDim:   dyn ? Qt.darker(Dyn.primary, 1.5) : "#8a5440"
    readonly property color vermDimDeep: dyn ? Qt.darker(Dyn.primary, 2.2) : "#5a3526"
    readonly property color vermBurn:  dyn ? Qt.darker(Dyn.primaryContainer, 1.1) : "#8a2c14"
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#cbb6a3"
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
    readonly property color flameCore: dyn ? Qt.lighter(onGlow, 1.03) : "#ffd9c2"
    readonly property color flameGlow: dyn ? onGlow : "#ff9a64"

    /**
     * Literal hex strings because a color property serializes to #aarrggbb and corrupts the Canvas gradient, so no Qt.darker math here.
     */
    readonly property string flameInk:   dyn ? Dyn.primary : "#f0795a"
    readonly property string flameEmber: dyn ? Dyn.primaryContainer : "#7e2812"
    readonly property string flameBurn:  dyn ? Dyn.primaryContainer : "#8a2c14"
    readonly property string flameTip:   dyn ? Dyn.onPrimaryContainer : "#ffb38a"
    readonly property color todayWarm: dyn ? onGlow : "#ffb38a"
    readonly property color ghost:     dyn ? Dyn.surfaceContainerHighest : "#594636"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.10)
    readonly property color creamMenu:     Qt.alpha(cream, 0.82)
    readonly property real shadowOpacity: 0.5
    /**
     * A snapshot and not a binding since Qt.fontFamilies() is not notifiable, so refreshFonts() runs once a dropped font's FontLoader is ready.
     */
    property var fontFamilies: Qt.fontFamilies()
    function refreshFonts() { fontFamilies = Qt.fontFamilies(); }
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

    /**
     * MPRIS trackArtists is an array from some players and a plain string from others (Spotify), where join would throw and kill the binding.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
