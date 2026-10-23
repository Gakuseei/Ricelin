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
        }
    }
}
