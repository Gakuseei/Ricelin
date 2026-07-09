pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Read-only view of the shared flags file the pill owns. The lock only cares
 * about the palette mode; this adapter carries a subset of the keys, so it
 * must never writeAdapter or it would strip the rest of the pill's state.
 */
Singleton {
    readonly property string paletteMode: adapter.paletteMode
    readonly property bool time12h: adapter.time12h

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
        }
    }
}
