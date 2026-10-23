import QtQuick
import "Singletons"

/** Dashed vermilion "+ label" bar that opens an add flow. */
Item {
    id: bar

    property real s: 1
    property string text: ""
    property bool lit: false

    readonly property bool hot: addArea.containsMouse || lit

    signal clicked()

    width: parent ? parent.width : 0
    height: 40 * bar.s

    Item {
        id: face
        anchors.fill: parent
        anchors.topMargin: Theme.sp.xs * bar.s
        anchors.bottomMargin: Theme.sp.xs * bar.s
        scale: addArea.pressed && !Motion.calm ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.r.m * bar.s
            color: Qt.alpha(Theme.vermLit, addArea.pressed ? 0.12 : (bar.hot ? 0.06 : 0))
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Canvas {
            id: dash
            anchors.fill: parent
            property color stroke: Qt.alpha(Theme.vermLit, bar.hot ? 0.7 : 0.36)
            onStrokeChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var r = Theme.r.m * bar.s;
                var w = width;
                var h = height;
                var p = 0.5;
                ctx.lineWidth = 1;
                ctx.strokeStyle = stroke;
                ctx.setLineDash([4 * bar.s, 4 * bar.s]);
                ctx.beginPath();
                ctx.moveTo(p + r, p);
                ctx.lineTo(w - p - r, p);
                ctx.arcTo(w - p, p, w - p, p + r, r);
                ctx.lineTo(w - p, h - p - r);
                ctx.arcTo(w - p, h - p, w - p - r, h - p, r);
                ctx.lineTo(p + r, h - p);
                ctx.arcTo(p, h - p, p, h - p - r, r);
                ctx.lineTo(p, p + r);
                ctx.arcTo(p, p, p + r, p, r);
                ctx.stroke();
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6 * bar.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: Theme.fs.title * bar.s
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.text
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * bar.s
                font.weight: Font.DemiBold
            }
        }
    }

    MouseArea {
        id: addArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bar.clicked()
    }
}
