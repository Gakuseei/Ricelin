pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Read-only subset view of the pill's shared flags file, which must never writeAdapter or it would strip the pill's other keys.
 */
Singleton {
    readonly property string paletteMode: adapter.paletteMode
    readonly property bool time12h: adapter.time12h
    readonly property real topGap: adapter.topGap
    readonly property string uiFont: adapter.uiFont
    readonly property bool clockSeconds: adapter.clockSeconds
    readonly property bool lockUseFont: adapter.lockUseFont
    readonly property bool lockSeconds: adapter.lockSeconds
    readonly property real uiScale: adapter.uiScale > 0 ? adapter.uiScale : 1
    readonly property real pillRounding: adapter.pillRounding

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string paletteMode: "static"
            property bool time12h: false
            property real topGap: 1.0
            property string uiFont: ""
            property bool clockSeconds: false
            property bool lockUseFont: true
            property bool lockSeconds: false
            property real uiScale: 1.0
            property real pillRounding: 18
        }
    }
}
