import QtQuick
import "Singletons"

/**
 * Horizontal twin of VFader with a trailing percent readout; the host drives `focused`, `on` saturates the fill, value is 0..1.
 */
Item {
    id: root

    property real s: 1
    property real value: 0.5
    property bool focused: false
    property bool on: true

    signal moved(real v)
    signal committed(real v)
    signal focusRequested()

    implicitHeight: 16 * s

    /** Nudge by a signed percentage, clamped, emitting both signals so the level follows each step. */
    function step(deltaPct) {
        const v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    readonly property real clamped: Math.max(0, Math.min(1, value))
    property string readout: Math.round(clamped * 100) + "%"

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: pct.left
        anchors.rightMargin: Theme.sp.s * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: 3 * root.s
        radius: height / 2
        color: Theme.threadBg

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.clamped
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.on ? Theme.vermBurn : Theme.vermDimDeep }
                GradientStop { position: 1.0; color: root.on ? Theme.vermLit : Theme.vermDim }
            }
            Behavior on width { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: tick
            x: Math.max(0, Math.min(track.width - width, track.width * root.clamped - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 2.5 * root.s
            height: 11 * root.s
            radius: 2 * root.s
            color: Theme.tickRest
            Behavior on x { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -8 * root.s
            preventStealing: true
            enabled: root.on
            function setFromX(mx) {
                const v = Math.max(0, Math.min(1, (mx + 8 * root.s) / track.width));
                root.moved(v);
            }
            onPressed: (e) => { root.focusRequested(); setFromX(e.x); }
            onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
            onReleased: root.committed(root.value)
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34 * root.s
        horizontalAlignment: Text.AlignRight
        text: root.readout
        color: root.focused ? Theme.cream : Theme.subtle
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }
}
