pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * One app in the dock: its icon, a pip for every open window and a brighter pip
 * when one of them has focus. Left click brings the app forward (or starts it),
 * middle click starts another instance, right click pins or unpins it.
 *
 * The icon springs towards the pointer with the same tuning the app tiles use.
 * The hover backing is not drawn here: the dock slides one shared lens under
 * whichever item the pointer is on, so this item only reports hover.
 *
 * `item` is a record from lib/dock.js (id, name, icon, cls, pinned, running,
 * active, minimized).
 */
Item {
    id: root

    property var item: null
    property real s: 1
    property real tile: 44 * s

    signal activated()
    signal launchNew()
    signal pinToggled()
    signal hoverChanged(bool on)

    readonly property bool hovered: area.containsMouse
    readonly property string title: item ? item.name : ""
    readonly property string desc: {
        if (!item)
            return "";
        var parts = [];
        if (item.running > 1)
            parts.push(item.running + " windows");
        else if (item.running === 1)
            parts.push(item.minimized ? "Minimized" : "Open");
        parts.push("Right-click to " + (item.pinned ? "unpin" : "pin"));
        return parts.join("  ·  ");
    }

    width: tile
    height: tile

    // New windows grow in instead of popping.
    scale: 0.6
    opacity: 0
    Component.onCompleted: enter.start()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: root; property: "scale"; to: 1; duration: Motion.standard; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Motion.fast }
    }

    // Focused app: a quiet backing so it reads at a glance.
    Rectangle {
        anchors.fill: parent
        radius: 15 * root.s
        color: Qt.alpha(Theme.bright, 0.09)
        border.width: 1
        border.color: Qt.alpha(Theme.bright, 0.16)
        opacity: root.item && root.item.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Item {
        id: iconBox
        anchors.centerIn: parent
        width: root.tile * 0.68
        height: width
        scale: area.pressed ? 0.9 : (area.containsMouse ? 1.16 : 1)
        Behavior on scale { SpringAnimation { spring: 3.5; damping: 0.3 } }
        // Minimized and not-running apps are a touch quieter than open ones.
        opacity: root.item && root.item.running > 0 && !root.item.minimized ? 1 : (root.item && root.item.minimized ? 0.62 : 0.9)

        Text {
            anchors.centerIn: parent
            visible: !icon.visible
            text: root.title.length > 0 ? root.title.charAt(0).toUpperCase() : "?"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: root.tile * 0.42
            font.weight: Font.DemiBold
        }

        Image {
            id: icon
            anchors.fill: parent
            sourceSize.width: Math.round(root.tile * 1.4)
            sourceSize.height: Math.round(root.tile * 1.4)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: status === Image.Ready && source != ""
            source: {
                if (!root.item)
                    return "";
                var name = root.item.icon && root.item.icon.length > 0 ? root.item.icon : String(root.item.cls || "").toLowerCase();
                if (name.length === 0)
                    return "";
                if (name.indexOf("/") === 0)
                    return "file://" + name;
                return Quickshell.iconPath(name, true);
            }
        }
    }

    // One pip per open window (three at most), on the edge of the dock that
    // faces the screen edge.
    Column {
        x: Dock.onRight ? root.width - width + 3.5 * root.s : -3.5 * root.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * root.s
        visible: root.item && root.item.running > 0

        Repeater {
            model: root.item ? Math.min(3, root.item.running) : 0

            Rectangle {
                required property int index
                width: 4 * root.s
                height: (root.item && root.item.active && index === 0 ? 10 : 4) * root.s
                radius: width / 2
                color: root.item && root.item.active ? Theme.onGlow : Qt.alpha(Theme.cream, 0.7)
                opacity: root.item && root.item.minimized ? 0.45 : 1
                Behavior on height { NumberAnimation { duration: Motion.fast } }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hoverChanged(containsMouse)
        onClicked: (e) => {
            if (e.button === Qt.RightButton)
                root.pinToggled();
            else if (e.button === Qt.MiddleButton)
                root.launchNew();
            else
                root.activated();
        }
    }
}
