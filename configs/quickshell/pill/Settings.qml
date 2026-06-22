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
        { item: lookRow, kind: "nav", surface: "look" },
        { item: displayRow, kind: "nav", surface: "display" },
        { item: inputRow, kind: "nav", surface: "input" },
        { item: animationRow, kind: "nav", surface: "animation" },
        { item: keybindsRow, kind: "nav", surface: "keybinds" },
        { item: idleRow, kind: "nav", surface: "idlelock" },
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
            captionOnFocus: true
            icon: "sparkles"
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
            id: lookRow
            surface: root
            captionOnFocus: true
            icon: "app-window"
            name: "Look"
            sub: "Gaps, rounding, blur, opacity"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === lookRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: displayRow
            surface: root
            captionOnFocus: true
            icon: "monitor"
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
            captionOnFocus: true
            icon: "mouse"
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

        SettingsRow {
            id: animationRow
            surface: root
            captionOnFocus: true
            icon: "waves"
            name: "Animation"
            sub: "Speed, motion curve, enable"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === animationRow ? Theme.cream : Theme.iconDim
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
            captionOnFocus: true
            icon: "keyboard"
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
            id: idleRow
            surface: root
            captionOnFocus: true
            icon: "lock"
            name: "Idle / Lock"
            sub: "Auto-lock, screen off, suspend"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === idleRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: updatesRow
            surface: root
            captionOnFocus: true
            icon: "download"
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
