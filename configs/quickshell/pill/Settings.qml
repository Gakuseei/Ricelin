pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 設 SETTINGS index: one row per category; a click or Enter morphs the pill into that category's surface.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    readonly property var categories: [
        { surface: "appearance", icon: "sparkles", name: "Appearance", sub: "Clock, glyphs, accent palette" },
        { surface: "look", icon: "app-window", name: "Look", sub: "Gaps, rounding, blur, opacity" },
        { surface: "display", icon: "monitor", name: "Display", sub: "Resolution, refresh, scale" },
        { surface: "input", icon: "mouse", name: "Input", sub: "Pointer, keyboard, cursor" },
        { surface: "animation", icon: "waves", name: "Animation", sub: "Speed, motion curve, enable" },
        { surface: "keybinds", icon: "keyboard", name: "Keybinds", sub: "Rebind, add, set commands" },
        { surface: "workspaces", icon: "layers", name: "Workspaces", sub: "Special spaces and their keys" },
        { surface: "idlelock", icon: "lock", name: "Idle / Lock", sub: "Auto-lock, screen off, suspend" },
        { surface: "updates", icon: "download", name: "Updates", sub: "Version and check for updates" }
    ]

    rows: {
        void catRep.count;
        var r = [];
        for (var i = 0; i < root.categories.length; i++) {
            var it = catRep.itemAt(i);
            if (it)
                r.push({ item: it, kind: "nav", surface: root.categories[i].surface });
        }
        return r;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Repeater {
            id: catRep
            model: root.categories

            SettingsRow {
                id: catRow
                required property var modelData
                required property int index
                surface: root
                captionOnFocus: true
                icon: catRow.modelData.icon
                name: catRow.modelData.name
                sub: catRow.modelData.sub
                last: catRow.index === root.categories.length - 1

                GlyphIcon {
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "chevron-right"
                    color: catRow.lit ? Theme.cream : Theme.iconDim
                    stroke: 2
                }
            }
        }
    }
}
