pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live wallpaper palette (surfaces and accents only) from the matugen JSON wallcolors.py writes, used by Theme only while the dynamic-palette flag is on.
 */
Singleton {
    id: root

    readonly property string surface: adapter.surface
    readonly property string surfaceContainerLow: adapter.surface_container_low
    readonly property string surfaceContainerHigh: adapter.surface_container_high
    readonly property string surfaceContainerHighest: adapter.surface_container_highest
    readonly property string primary: adapter.primary
    readonly property string primaryContainer: adapter.primary_container
    readonly property string onPrimaryContainer: adapter.on_primary_container
    readonly property string outlineVariant: adapter.outline_variant
    readonly property string cream: adapter.cream
    readonly property string bright: adapter.bright
    readonly property string subtle: adapter.subtle
    readonly property string dim: adapter.dim
    readonly property string faint: adapter.faint
    readonly property string iconDim: adapter.icon_dim
    readonly property string tickRest: adapter.tick_rest

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property string surface: "#18120b"
            property string surface_container_low: "#211b13"
            property string surface_container_high: "#302921"
            property string surface_container_highest: "#3b342b"
            property string primary: "#f5bd6f"
            property string primary_container: "#633f00"
            property string on_primary_container: "#ffddb3"
            property string outline_variant: "#4f4539"
            property string cream: "#e6d6cb"
            property string bright: "#fff6f0"
            property string subtle: "#b9a99e"
            property string dim: "#8a7d74"
            property string faint: "#6f635b"
            property string icon_dim: "#cdbfb4"
            property string tick_rest: "#cbb6a3"
        }
    }
}
