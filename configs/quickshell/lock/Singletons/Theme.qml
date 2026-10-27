pragma Singleton
import QtQuick
import Quickshell

/**
 * Lock palette: washi by default, the wallpaper's with the dynamic palette.
 */
Singleton {
    readonly property bool dyn: Flags.paletteMode !== "static"
    readonly property color verm:   dyn ? Qt.darker(Dyn.primary, 1.18) : "#c0442b"
    readonly property color cream:  dyn ? Dyn.cream : "#e6d6cb"
    readonly property color bright: dyn ? Dyn.bright : "#fff6f0"
    readonly property color dim:    dyn ? Dyn.dim : "#8a7d74"
    /** The pill's UI font when the lock follows it and it is installed, else Inter. */
    readonly property string font: Flags.lockUseFont && Flags.uiFont.length > 0 && Qt.fontFamilies().indexOf(Flags.uiFont) >= 0 ? Flags.uiFont : "Inter"

    readonly property color fieldBg: dyn ? Qt.alpha(bright, 0.10) : Qt.rgba(1, 0.96, 0.94, 0.10)
    readonly property color fieldBorder: dyn ? Qt.alpha(cream, 0.30) : Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.30)
    readonly property color trackBg: dyn ? Qt.alpha(cream, 0.16) : Qt.rgba(240 / 255, 224 / 255, 215 / 255, 0.16)
    readonly property color error:  dyn ? Dyn.primary : "#e0563b"
}
