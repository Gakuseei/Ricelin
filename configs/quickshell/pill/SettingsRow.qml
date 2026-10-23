pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The one settings line: icon or kanji, name, caption, and a control on the right; hover never changes its height.
 */
Item {
    id: srow

    property var surface: null
    property string glyph: ""
    property string icon: ""
    property string name: ""
    property string label: ""
    property string sub: ""
    property string caption: ""
    property bool last: false
    property bool captionOnFocus: false
    property bool collapsed: false
    default property alias control: controlSlot.data

    readonly property real s: srow.surface ? srow.surface.s : 1
    readonly property bool focused: srow.surface ? srow.surface.focusRowItem === srow : false
    readonly property string title: name.length > 0 ? name : label
    readonly property string note: sub.length > 0 ? sub : caption
    readonly property bool lit: srowHover.hovered || srow.focused
    readonly property bool lead: (icon.length > 0) || (glyph.length > 0 && Flags.showGlyphs)

    width: parent ? parent.width : 0
    height: collapsed ? 0 : Math.max(36 * s, (captionOnFocus ? titleText.implicitHeight : textCol.implicitHeight) + 16 * s)
    clip: collapsed || heightAnim.running
    Behavior on height { NumberAnimation { id: heightAnim; duration: 200; easing.type: Easing.OutCubic } }

    HoverHandler {
        id: srowHover
        enabled: !srow.collapsed
        onHoveredChanged: if (srow.surface) srow.surface.reportRowHover(srow, hovered)
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2 * srow.s
        anchors.bottomMargin: 2 * srow.s
        radius: Theme.r.m * srow.s
        color: press.pressed ? Theme.pressBg : (srow.lit ? Theme.frameBg : "transparent")
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: press
        anchors.fill: parent
        enabled: !srow.collapsed
        cursorShape: Qt.PointingHandCursor
        onClicked: if (srow.surface) srow.surface.activateRow(srow)
    }

    Item {
        id: leadSlot
        anchors.left: parent.left
        anchors.leftMargin: 12 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        width: 16 * srow.s
        height: width
        visible: srow.lead

        GlyphIcon {
            anchors.centerIn: parent
            width: 16 * srow.s
            height: width
            visible: srow.icon.length > 0
            name: srow.icon
            color: srow.lit ? Theme.cream : Theme.subtle
            stroke: 1.8
        }

        Text {
            anchors.centerIn: parent
            visible: srow.icon.length === 0
            text: srow.glyph
            color: Theme.iconDim
            font.family: Theme.fontJp
            font.pixelSize: Theme.fs.title * srow.s
        }
    }

    Column {
        id: textCol
        anchors.left: parent.left
        anchors.leftMargin: (srow.lead ? 40 : 12) * srow.s
        anchors.right: controlSlot.left
        anchors.rightMargin: 12 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * srow.s

        Text {
            id: titleText
            width: parent.width
            text: srow.title
            color: Theme.cream
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * srow.s
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: srow.note.length > 0 && !srow.captionOnFocus
            text: srow.note
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * srow.s
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }
    }

    /**
     * A hover caption fades into the free space between title and control, never squeezing the title.
     */
    Text {
        id: inlineNote
        anchors.right: controlSlot.left
        anchors.rightMargin: 10 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(implicitWidth, controlSlot.x - 10 * srow.s - textCol.x - titleText.implicitWidth - 16 * srow.s))
        visible: srow.captionOnFocus && srow.note.length > 0
        opacity: srow.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        text: srow.note
        color: Theme.textFaint
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * srow.s
    }

    Item {
        id: controlSlot
        anchors.right: parent.right
        anchors.rightMargin: 12 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 12 * srow.s
        anchors.right: parent.right
        anchors.rightMargin: 12 * srow.s
        height: 1
        color: Theme.hairSoft
        visible: !srow.last && !srow.collapsed
    }
}
