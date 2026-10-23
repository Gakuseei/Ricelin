import QtQuick
import "Singletons"

/**
 * Inline actions under a list row: a quiet status on the left, Buttons on the right.
 */
Item {
    id: confirm

    property real s: 1
    property string status: ""
    property real inset: Theme.sp.m
    default property alias buttons: btnRow.data

    width: parent ? parent.width : 0
    height: 36 * s

    Text {
        anchors.left: parent.left
        anchors.leftMargin: confirm.inset * confirm.s
        anchors.right: btnRow.left
        anchors.rightMargin: Theme.sp.s * confirm.s
        anchors.verticalCenter: parent.verticalCenter
        text: confirm.status
        color: Theme.textFaint
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * confirm.s
    }

    Row {
        id: btnRow
        anchors.right: parent.right
        anchors.rightMargin: confirm.inset * confirm.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp.xs * confirm.s
    }
}
