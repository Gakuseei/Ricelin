pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications
import "Singletons"

/**
 * Toast card inside the pill: click opens the app, a drag carries the pill and flings it out past half its size or on a flick.
 */
Item {
    id: root

    property real s: 1
    property bool live: true
    required property var notif
    readonly property var n: notif || ({})
    required property Item host

    readonly property bool critical: n.urgency === NotificationUrgency.Critical
    readonly property var acts: n.actions ? n.actions.filter(function(a) { return a.text.length > 0; }) : []

    implicitHeight: Math.max(iconTile.height, col.implicitHeight)

    /**
     * Snapshotted once: a binding to Notifs.expireAt would restart the timer whenever another notification lands.
     */
    property double deadline: 0
    function armDeadline() { deadline = notif ? (Notifs.expireAt[notif.id] || (Date.now() + 4000)) : 0; }
    Component.onCompleted: armDeadline()

    Timer {
        interval: Math.max(300, root.deadline - Date.now())
        running: root.deadline > 0 && root.live && !swipe.pressed && root.n.urgency !== NotificationUrgency.Critical
        onTriggered: Notifs.removePopup(root.notif)
    }

    /**
     * After a swipe the next card enters from the side the last one left through; otherwise it settles in place.
     */
    property real enterX: 0
    property real enterY: 0
    onNotifChanged: {
        if (!notif)
            return;
        armDeadline();
        if (enterX === 0 && enterY === 0) {
            arriveAnim.restart();
            return;
        }
        host.swipeFade = 0;
        settle(enterX, enterY, 0, 0, 1);
        enterX = 0;
        enterY = 0;
    }

    /**
     * Springs the card home from where and how fast it was let go; damping 1 for a card that simply enters.
     */
    function settle(x, y, vx, vy, damping) {
        backX.damping = damping;
        backX.launch(x, vx, 0);
        backY.launch(y, vy, 0);
        fadeIn.restart();
    }

    Spring {
        id: backX
        response: 0.3
        damping: 0.8
        onValueChanged: if (running) root.host.swipeX = value
    }
    Spring {
        id: backY
        response: 0.3
        damping: backX.damping
        onValueChanged: if (running) root.host.swipeY = value
    }
    NumberAnimation { id: fadeIn; target: root.host; property: "swipeFade"; to: 1; duration: Motion.standard; easing.type: Motion.easeStandard }

    property real arrive: 1
    opacity: 0.25 + 0.75 * arrive
    transform: Translate { y: Motion.calm ? 0 : 6 * root.s * (1 - root.arrive) }
    NumberAnimation { id: arriveAnim; target: root; property: "arrive"; from: 0; to: 1; duration: Motion.glide; easing.type: Easing.OutCubic }

    /**
     * Leaves at the speed of the release: OutQuad starts at twice its average speed.
     */
    ParallelAnimation {
        id: fling
        property real toX: 0
        property real toY: 0
        property int ms: 140
        NumberAnimation { target: root.host; property: "swipeX"; to: fling.toX; duration: fling.ms; easing.type: Easing.OutQuad }
        NumberAnimation { target: root.host; property: "swipeY"; to: fling.toY; duration: fling.ms; easing.type: Easing.OutQuad }
        NumberAnimation { target: root.host; property: "swipeFade"; to: 0; duration: fling.ms; easing.type: Easing.OutQuad }
        onFinished: {
            root.enterX = -fling.toX;
            root.enterY = -fling.toY;
            Notifs.removePopup(root.notif);
        }
    }

    /**
     * Tracked in window coords: the pill moves under the cursor, so item-local deltas would collapse to zero.
     */
    MouseArea {
        id: swipe
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        property real px: 0
        property real py: 0
        property string axis: ""
        property var samples: []

        readonly property real slack: 8 * root.s
        readonly property real farX: root.host.width / 2
        readonly property real farY: root.host.height * 0.6

        function fadeFor(moved, far) { return 1 - 0.6 * Math.min(1, moved / far); }

        onPressed: function(m) {
            backX.snap(root.host.swipeX);
            backY.snap(root.host.swipeY);
            const p = mapToItem(null, m.x, m.y);
            px = p.x;
            py = p.y;
            axis = "";
            samples = [];
        }
        onPositionChanged: function(m) {
            const p = mapToItem(null, m.x, m.y);
            const dx = p.x - px;
            const dy = p.y - py;
            if (axis === "" && Math.max(Math.abs(dx), Math.abs(dy)) > slack)
                axis = Math.abs(dx) > Math.abs(dy) ? "x" : "y";
            const now = Date.now();
            samples = samples.filter(sm => now - sm.t < 80).concat([{ t: now, x: dx, y: dy }]);
            if (axis === "x") {
                root.host.swipeX = dx;
                root.host.swipeFade = fadeFor(Math.abs(root.host.swipeX), farX);
            } else if (axis === "y") {
                const h = root.host.height;
                root.host.swipeY = dy < 0 ? dy : dy * h * 0.55 / (h + 0.55 * dy);
                root.host.swipeFade = fadeFor(Math.max(0, -root.host.swipeY), farY);
            }
        }
        onReleased: function(m) {
            if (axis === "") {
                Notifs.activateNotif(root.notif);
                Notifs.removePopup(root.notif);
                return;
            }
            const h = root.host;
            const first = samples.length ? samples[0] : null;
            const last = samples.length ? samples[samples.length - 1] : null;
            const dt = first && last && last.t > first.t ? (last.t - first.t) / 1000 : 0;
            const vx = dt ? (last.x - first.x) / dt : 0;
            const vy = dt ? (last.y - first.y) / dt : 0;
            const v = axis === "x" ? Math.abs(vx) : -vy;
            const moved = axis === "x" ? Math.abs(h.swipeX) : -h.swipeY;
            const quick = v > 500 * root.s && (axis === "y" || Math.sign(vx) === Math.sign(h.swipeX));
            if (moved >= (axis === "x" ? farX : farY) || quick) {
                fling.toX = axis === "x" ? (h.swipeX < 0 ? -h.width : h.width) : 0;
                fling.toY = axis === "y" ? -h.height * 1.3 : 0;
                const left = axis === "x" ? Math.abs(fling.toX - h.swipeX) : Math.abs(fling.toY - h.swipeY);
                fling.ms = Math.max(90, Math.min(220, 2000 * left / Math.max(v, 1)));
                fling.restart();
            } else {
                root.settle(h.swipeX, h.swipeY, vx, vy, 0.8);
            }
        }
    }

    Rectangle {
        id: iconTile
        anchors.left: parent.left
        anchors.top: parent.top
        width: 28 * root.s
        height: 28 * root.s
        radius: Theme.r.m * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border

        Image {
            id: toastImg
            anchors.fill: parent
            anchors.margins: root.n.image ? 0 : 6 * root.s
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

    GlyphIcon {
        id: dismiss
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.sp.xxs * root.s
        width: 11 * root.s
        height: 11 * root.s
        name: "close"
        stroke: 1.9
        color: dismissArea.containsMouse ? Theme.cream : Theme.textFaint
        scale: dismissArea.pressed && !Motion.calm ? 0.85 : 1
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        MouseArea {
            id: dismissArea
            anchors.fill: parent
            anchors.margins: -Theme.sp.s * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Notifs.removePopup(root.notif)
        }
    }

    Column {
        id: col
        anchors.left: iconTile.right
        anchors.leftMargin: Theme.sp.m * root.s
        anchors.right: dismiss.left
        anchors.rightMargin: Theme.sp.s * root.s
        anchors.top: parent.top
        spacing: Theme.sp.xxs * root.s

        Text {
            width: parent.width
            text: (root.n.appName && root.n.appName.length) ? root.n.appName : "System"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.label * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Theme.labelTracking * root.s
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Row {
            width: parent.width
            spacing: Theme.sp.xs * root.s

            Item {
                visible: root.critical
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s

                Rectangle {
                    anchors.centerIn: parent
                    width: 8 * root.s
                    height: 8 * root.s
                    radius: Theme.r.full
                    color: Theme.flameGlow
                    opacity: 0.3
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4 * root.s
                    height: 4 * root.s
                    radius: Theme.r.full
                    color: Theme.flameGlow
                }
            }

            Text {
                width: parent.width - (root.critical ? 12 * root.s : 0)
                text: Notifs.plain(root.n.summary)
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.body * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: Notifs.plain(root.n.body)
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Row {
            visible: root.acts.length > 0
            spacing: Theme.sp.s * root.s
            topPadding: Theme.sp.xs * root.s

            Repeater {
                model: root.acts

                Button {
                    required property var modelData
                    required property int index

                    s: root.s
                    text: modelData.text
                    kind: index === 0 ? "secondary" : "ghost"
                    onClicked: {
                        modelData.invoke();
                        if (modelData.identifier === "default")
                            Notifs.raiseWindow(root.notif);
                        Notifs.removePopup(root.notif);
                    }
                }
            }
        }
    }
}
