import QtQuick
import QtQuick.Effects
import "app.js" as App

/** Centres its one child and, only while that child is wider than this box, clips it with soft faded edges instead of scaling it. */
Item {
    id: fade

    property real s: App.shell ? App.shell.s : 1
    property real edge: 56 * s
    property real pad: 16 * s
    default property alias content: holder.data

    readonly property real contentW: holder.childrenRect.width
    readonly property real contentH: holder.childrenRect.height
    readonly property bool overflow: contentW > width + 0.5

    implicitHeight: contentH + 2 * pad

    Item {
        id: inner
        anchors.fill: parent
        clip: fade.overflow
        layer.enabled: fade.overflow
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }

        Item {
            id: holder
            x: (fade.width - fade.contentW) / 2
            y: fade.pad
            width: fade.contentW
            height: fade.contentH
        }
    }

    Item {
        id: mask
        width: fade.width
        height: fade.height
        visible: false
        layer.enabled: true

        Rectangle {
            id: ramp
            anchors.fill: parent
            readonly property real e: fade.width > 0 ? Math.min(0.45, fade.edge / fade.width) : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: ramp.e; color: "white" }
                GradientStop { position: 1 - ramp.e; color: "white" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
