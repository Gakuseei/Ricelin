import QtQuick
import "Singletons"

/**
 * Vertical thread fader with a flat tick, readout and label always shown; the host drives `focused`, value is 0..1.
 */
Item {
    id: root

    property real s: 1
    property string icon: ""
    property real value: 0.5
    property string valueLabel: ""
    property string subLabel: ""
    property bool focused: false

    signal moved(real v)
    signal committed(real v)

    readonly property bool lit: focused

    readonly property real trackH: 86 * s

    /** Live tick centre; tick.y and width are voided because mapToItem alone never re-runs on a move. */
    readonly property point tickCenter: {
        void tick.y;
        void root.width;
        return tick.mapToItem(root, tick.width / 2, tick.height / 2);
    }

    implicitWidth: 54 * s
    implicitHeight: trackH + (subLabel.length ? 56 : 44) * s

    /** Nudge by a signed percentage, clamped, emitting both signals so hardware follows each step. */
    function step(deltaPct) {
        const v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    Item {
        id: trackArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 22 * root.s
        height: root.trackH

        Rectangle {
            id: thread
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2 * root.s
            height: parent.height
            radius: width / 2
            color: Theme.threadBg

            Rectangle {
                id: fill
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * Math.max(0, Math.min(1, root.value))
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.lit ? Theme.vermLit : Theme.vermDim }
                    GradientStop { position: 1.0; color: root.lit ? Theme.vermBurn : Theme.vermDimDeep }
                }
                Behavior on height { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }

        }

        Rectangle {
            id: tick
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, Math.min(root.trackH - height,
                (1 - Math.max(0, Math.min(1, root.value))) * root.trackH - height / 2))
            width: 11 * root.s
            height: 2.5 * root.s
            radius: 2 * root.s
            color: Theme.tickRest
            opacity: root.focused ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -10 * root.s
            preventStealing: true
            function setFromY(my) {
                const v = 1 - Math.max(0, Math.min(1, (my - 10 * root.s) / root.trackH));
                root.moved(v);
            }
            onPressed: (e) => setFromY(e.y)
            onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
            onReleased: root.committed(root.value)
        }
    }

    Text {
        id: readout
        anchors.top: trackArea.bottom
        anchors.topMargin: 7 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.valueLabel
        color: root.lit ? Theme.cream : Theme.subtle
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
    }

    Item {
        id: iconBox
        anchors.top: readout.bottom
        anchors.topMargin: Theme.sp.xxs * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: 18 * root.s
        height: 18 * root.s

        GlyphIcon {
            anchors.fill: parent
            name: root.icon
            color: root.lit ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }
    }

    Text {
        visible: root.subLabel.length > 0
        anchors.top: iconBox.bottom
        anchors.topMargin: 1 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, root.width - Theme.sp.xs * root.s)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.subLabel
        color: root.lit ? Theme.cream : Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.DemiBold
        Behavior on color { ColorAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
    }
}
