import QtQuick
import QtQuick.Controls
import "../Singletons"
import "app.js" as App

/** Slim scrollbar for any Flickable: attach as `ScrollBar.vertical: AppScrollBar {}`. */
ScrollBar {
    id: bar

    property real s: App.shell ? App.shell.s : 1

    policy: ScrollBar.AsNeeded
    padding: 2 * s
    implicitWidth: 10 * s
    minimumSize: 0.08

    background: null
    contentItem: Rectangle {
        implicitWidth: 4 * bar.s
        radius: width / 2
        color: Qt.alpha(Theme.cream, bar.pressed ? 0.28 : (bar.hovered ? 0.2 : 0.12))
        opacity: bar.active || bar.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }
}
