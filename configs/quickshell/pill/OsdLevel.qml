import QtQuick
import "Singletons"

/**
 * The OSD level line shared by volume, brightness and battery: glyph, a fill that glides as a fraction, and a readout.
 */
Item {
    id: lv

    property real s: 1
    property string icon
    property color iconColor: Theme.iconDim
    property real frac: 0
    property string readout: ""
    property bool muted: false
    property color fill: Theme.vermLit
    property bool ember: false
    property bool shimmer: false

    anchors.fill: parent

    property real shownFrac: Math.max(0, Math.min(1, frac))
    Behavior on shownFrac { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

    GlyphIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 17 * lv.s
        height: 17 * lv.s
        name: lv.icon
        color: lv.iconColor
        stroke: 1.7
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36 * lv.s
        horizontalAlignment: Text.AlignRight
        text: lv.readout
        color: lv.muted ? Theme.textFaint : Theme.cream
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * lv.s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    Rectangle {
        anchors.left: glyph.right
        anchors.leftMargin: Theme.sp.m * lv.s
        anchors.right: pct.left
        anchors.rightMargin: Theme.sp.m * lv.s
        anchors.verticalCenter: parent.verticalCenter
        height: 4 * lv.s
        radius: height / 2
        color: Theme.threadBg
        clip: lv.shimmer

        Rectangle {
            id: bar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * lv.shownFrac
            radius: parent.radius
            color: lv.muted ? Theme.vermDim : lv.fill
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: lv.ember
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.vermDeep }
                    GradientStop { position: 1.0; color: Theme.flameGlow }
                }
            }

            Rectangle {
                visible: lv.shimmer
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 34 * lv.s
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.bright, 0) }
                    GradientStop { position: 0.5; color: Qt.alpha(Theme.cream, 0.33) }
                    GradientStop { position: 1.0; color: Qt.alpha(Theme.bright, 0) }
                }

                NumberAnimation on x {
                    from: -34 * lv.s
                    to: bar.width
                    duration: Motion.heat
                    loops: Animation.Infinite
                    running: lv.shimmer && lv.visible && !Motion.calm
                }
            }
        }
    }
}
