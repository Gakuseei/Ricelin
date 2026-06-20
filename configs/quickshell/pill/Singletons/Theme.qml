pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette. Two sources: the curated washi/flame hex below is the identity
 * and the default, used whenever the dynamic-palette flag is off. With the flag
 * on, the surfaces and the whole accent ramp follow the wallpaper through the
 * matugen-fed `Dyn` singleton, while the text family, light veils and shadow
 * stay locked here so copy keeps its contrast on any generated background. Each
 * token is a single ternary, so static mode renders byte-identical to the fixed
 * theme and only the colours that should breathe with the wallpaper do.
 */
Singleton {
    readonly property bool dyn: Flags.dynamicPalette

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
    readonly property color vermDim:   dyn ? Qt.darker(Dyn.primary, 1.5) : "#8a5440"
    readonly property color vermDimDeep: dyn ? Qt.darker(Dyn.primary, 2.2) : "#5a3526"
    readonly property color vermBurn:  dyn ? Qt.darker(Dyn.primaryContainer, 1.1) : "#8a2c14"
    readonly property color tickRest:  dyn ? Dyn.tickRest : "#cbb6a3"
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
    readonly property color flameCore: dyn ? Qt.lighter(Dyn.onPrimaryContainer, 1.03) : "#ffd9c2"
    readonly property color flameGlow: dyn ? Dyn.onPrimaryContainer : "#ff9a64"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render, so the dynamic branch passes
     * matugen's raw hex strings through untouched rather than any Qt.darker math.
     */
    readonly property string flameInk:   dyn ? Dyn.primary : "#f0795a"
    readonly property string flameEmber: dyn ? Dyn.primaryContainer : "#7e2812"
    readonly property string flameBurn:  dyn ? Dyn.primaryContainer : "#8a2c14"
    readonly property string flameTip:   dyn ? Dyn.onPrimaryContainer : "#ffb38a"
    readonly property color todayWarm: dyn ? Dyn.onPrimaryContainer : "#ffb38a"
    readonly property color ghost:     dyn ? Dyn.surfaceContainerHighest : "#594636"
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.10)
    readonly property color creamMenu:     Qt.alpha(cream, 0.82)
    readonly property real shadowOpacity: 0.5
    readonly property string font: "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
