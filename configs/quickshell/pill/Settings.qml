pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 設 SETTINGS index: a short list of categories grouped into Shell and Control.
 * Each row carries its kanji, name and caption, and morphs the pill into that
 * category's sub-surface. Arrow keys move the focused row with the glowing seam
 * and Return opens it. The Shell group holds Appearance and Display; the Control
 * group holds Keybinds and Updates.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: displayRow, kind: "nav", surface: "display" },
        { item: inputRow, kind: "nav", surface: "input" },
        { item: keybindsRow, kind: "nav", surface: "keybinds" },
        { item: updatesRow, kind: "nav", surface: "updates" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Shell"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SettingsRow {
            id: appearanceRow
            surface: root
            glyph: "相"
            name: "Appearance"
            sub: "Clock, glyphs, accent palette"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: displayRow
            surface: root
            glyph: "画"
            name: "Display"
            sub: "Resolution, refresh, scale"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === displayRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: inputRow
            surface: root
            glyph: "操"
            name: "Input"
            sub: "Pointer, keyboard, cursor"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === inputRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Control"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SettingsRow {
            id: keybindsRow
            surface: root
            glyph: "鍵"
            name: "Keybinds"
            sub: "Rebind, add, set commands"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === keybindsRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: updatesRow
            surface: root
            glyph: "更"
            name: "Updates"
            sub: "Version and check for updates"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === updatesRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }
    }
}
