import QtQuick
import "Singletons"

/** Dashed vermilion "+ label" bar that opens an add flow. */
Item {
    id: bar

    property real s: 1
    property string text: ""

    signal clicked()

    width: parent ? parent.width : 0
    height: 40 * bar.s

    Canvas {
        id: dash
        anchors.fill: parent
        anchors.topMargin: 4 * bar.s
        anchors.bottomMargin: 4 * bar.s
        property color stroke: Qt.alpha(Theme.vermLit, addArea.containsMouse ? 0.7 : 0.36)
        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = 9 * bar.s;
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
            font.pixelSize: 14 * bar.s
            font.weight: Font.Bold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.text
            color: Theme.vermLit
            font.family: Theme.font
            font.pixelSize: 11 * bar.s
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5 * bar.s
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
