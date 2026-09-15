pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "Singletons"

/**
 * Toast content for the morphing pill body: icon tile, app eyebrow, summary
 * with critical ember dot, optional body text and action pills, dismiss glyph
 * on the right. Draws no background of its own; the pill body behind it
 * provides the washi material. Clicking the body jumps to the source app;
 * dismiss and action pills consume their clicks. Dragging the body up, left
 * or right drags the whole host pill along 1:1 into the mask wall; past half
 * the width (0.6 height going up) or on a quick flick it flings out, shorter
 * pulls spring back. Auto-expires via Notifs.expireAt unless the notification is
 * critical.
 */
Item {
    id: root

    property real s: 1
    property bool live: true
    required property var notif
    required property Item host

    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property var acts: notif.actions.filter(function(a) { return a.text.length > 0; })

    implicitHeight: Math.max(iconTile.height, col.implicitHeight)

    /**
     * Deadline is snapshotted once: binding the interval to Notifs.expireAt
     * restarts the timer (and drifts the lifetime) every time an unrelated
     * notification replaces the map.
     */
    property double deadline: 0
    function armDeadline() { deadline = notif ? (Notifs.expireAt[notif.id] || (Date.now() + 6000)) : 0; }
    Component.onCompleted: armDeadline()

    Timer {
        interval: Math.max(300, root.deadline - Date.now())
        running: root.deadline > 0 && root.live && !swipe.pressed && root.notif.urgency !== NotificationUrgency.Critical
        onTriggered: Notifs.removePopup(root.notif)
    }

    /**
     * Same Toast instance keeps showing the stack after a swipe, so the next
     * card enters from the side the last one left through.
     */
    property real enterX: 0
    property real enterY: 0
    onNotifChanged: {
        if (!notif)
            return;
        armDeadline();
        if (enterX === 0 && enterY === 0)
            return;
        host.swipeX = enterX;
        host.swipeY = enterY;
        host.swipeFade = 0;
        enterX = 0;
        enterY = 0;
        settle.restart();
    }

    ParallelAnimation {
        id: settle
        NumberAnimation { target: root.host; property: "swipeX"; to: 0; duration: Motion.standard; easing.type: Easing.OutBack }
        NumberAnimation { target: root.host; property: "swipeY"; to: 0; duration: Motion.standard; easing.type: Easing.OutBack }
        NumberAnimation { target: root.host; property: "swipeFade"; to: 1; duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    ParallelAnimation {
        id: fling
        property real toX: 0
        property real toY: 0
        NumberAnimation { target: root.host; property: "swipeX"; to: fling.toX; duration: Motion.fast; easing.type: Easing.InCubic }
        NumberAnimation { target: root.host; property: "swipeY"; to: fling.toY; duration: Motion.fast; easing.type: Easing.InCubic }
        NumberAnimation { target: root.host; property: "swipeFade"; to: 0; duration: Motion.fast; easing.type: Easing.InCubic }
        onFinished: {
            root.enterX = -fling.toX;
            root.enterY = -fling.toY;
            Notifs.removePopup(root.notif);
        }
    }

    /**
     * Pointer is tracked in window coords: the pill moves under the cursor
     * while dragging, so item-local deltas would collapse to zero.
     */
    MouseArea {
        id: swipe
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        property real px: 0
        property real py: 0
        property double pt: 0
        property string axis: ""

        readonly property real slack: 8 * root.s
        readonly property real farX: root.host.width / 2
        readonly property real farY: root.host.height * 0.6

        function fadeFor(moved, far) { return 1 - 0.6 * Math.min(1, moved / far); }

        onPressed: function(m) {
            settle.stop();
            const p = mapToItem(null, m.x, m.y);
            px = p.x;
            py = p.y;
            pt = Date.now();
            axis = "";
        }
        onPositionChanged: function(m) {
            const p = mapToItem(null, m.x, m.y);
            const dx = p.x - px;
            const dy = p.y - py;
            if (axis === "" && Math.max(Math.abs(dx), Math.abs(dy)) > slack)
                axis = Math.abs(dx) > Math.abs(dy) ? "x" : "y";
            if (axis === "x") {
                root.host.swipeX = dx;
                root.host.swipeFade = fadeFor(Math.abs(root.host.swipeX), farX);
            } else if (axis === "y") {
                root.host.swipeY = Math.min(0, dy);
                root.host.swipeFade = fadeFor(-root.host.swipeY, farY);
            }
        }
        onReleased: function(m) {
            if (axis === "") {
                Notifs.activateNotif(root.notif);
                Notifs.removePopup(root.notif);
                return;
            }
            const h = root.host;
            const flick = Date.now() - pt < 250;
            const moved = axis === "x" ? Math.abs(h.swipeX) : -h.swipeY;
            const far = moved >= (axis === "x" ? farX : farY);
            if (far || (flick && moved > slack * 2)) {
                fling.toX = axis === "x" ? (h.swipeX < 0 ? -h.width : h.width) : 0;
                fling.toY = axis === "y" ? -h.height * 1.3 : 0;
                fling.restart();
            } else {
                settle.restart();
            }
        }
    }

    Rectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28 * root.s
        height: 28 * root.s
        radius: 9 * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border

        Image {
            id: toastImg
            anchors.fill: parent
            anchors.margins: root.notif.image ? 0 : 6 * root.s
            source: Notifs.iconFor(root.notif)
            sourceSize.width: 56
            sourceSize.height: 56
            fillMode: Image.PreserveAspectCrop
            smooth: true
            visible: source.toString().length > 0
        }

        Rectangle {
            anchors.centerIn: parent
            visible: !toastImg.visible
            width: 7 * root.s
            height: 7 * root.s
            radius: 2 * root.s
            rotation: 45
            color: root.critical ? Theme.vermLit : Theme.verm
        }
    }

    Text {
        id: dismiss
        anchors.right: parent.right
        anchors.top: parent.top
        text: "✕"
        color: dismissArea.containsMouse ? Theme.cream : Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * root.s

        Behavior on color {
            ColorAnimation { duration: Motion.fast }
        }

        MouseArea {
            id: dismissArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.removePopup(root.notif)
        }
    }

    Column {
        id: col
        anchors.left: iconTile.right
        anchors.leftMargin: 10 * root.s
        anchors.right: dismiss.left
        anchors.rightMargin: 8 * root.s
        anchors.top: parent.top
        spacing: 3 * root.s

        Text {
            width: parent.width
            text: (root.notif.appName && root.notif.appName.length) ? root.notif.appName : "System"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4 * root.s
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 5 * root.s

            Item {
                visible: root.critical
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s

                Rectangle {
                    anchors.centerIn: parent
                    width: 8 * root.s
                    height: 8 * root.s
                    radius: 999
                    color: Theme.flameGlow
                    opacity: 0.3
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4 * root.s
                    height: 4 * root.s
                    radius: 999
                    color: Theme.flameGlow
                }
            }

            Text {
                width: parent.width - (root.critical ? 13 * root.s : 0)
                text: root.notif.summary
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }

        Text {
            width: parent.width
            visible: root.notif.body.length > 0
            text: root.notif.body
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Row {
            visible: root.acts.length > 0
            spacing: 6 * root.s
            topPadding: 4 * root.s

            Repeater {
                model: root.acts

                Rectangle {
                    id: actPill
                    required property var modelData
                    required property int index

                    height: 20 * root.s
                    width: actText.implicitWidth + 18 * root.s
                    radius: 999
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: actText
                        anchors.centerIn: parent
                        text: actPill.modelData.text
                        color: actPill.index === 0 ? Theme.vermLit : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actPill.modelData.invoke();
                            if (actPill.modelData.identifier === "default")
                                Notifs.raiseWindow(root.notif);
                            Notifs.removePopup(root.notif);
                        }
                    }
                }
            }
        }
    }
}
