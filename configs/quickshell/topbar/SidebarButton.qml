import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: btn

    property real s: 1
    property string screenName: ""

    readonly property color vermLit: "#e0563b"
    readonly property color sheen: Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.07)

    implicitWidth: 28 * btn.s
    implicitHeight: 28 * btn.s

    Rectangle {
        id: hover
        anchors.fill: parent
        radius: 7 * btn.s
        color: btn.sheen
        opacity: area.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Image {
        id: glyph
        anchors.centerIn: parent
        width: 16 * btn.s
        height: 16 * btn.s
        source: Qt.resolvedUrl("assets/icons/sidebar.svg")
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: glyph
        source: glyph
        colorization: 1.0
        colorizationColor: btn.vermLit
        opacity: area.containsMouse ? 1 : 0.82
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["sh", "-c", "qs -c sidebar ipc call sidebar toggle '" + btn.screenName + "' 2>/dev/null || true"])
    }
}
