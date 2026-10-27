import QtQuick
import "Singletons"

/**
 * What is running beside the resting clock: the first active source in `Flags.liveOrder` that `Flags.liveOff` leaves on.
 */
Item {
    id: act

    property real s: 1

    readonly property var sources: (Flags.liveOrder || []).filter(k => (Flags.liveOff || []).indexOf(k) < 0)
    readonly property string kind: {
        for (const k of sources)
            if (isActive(k))
                return k;
        return "";
    }
    readonly property bool waits: kind === "agent" && Agents.top !== null && Agents.top.status === "wait"
    readonly property bool scrolls: kind === "message" || kind === "music"

    function isActive(k) {
        switch (k) {
        case "agent":
            return Agents.top !== null;
        case "timer":
            return Countdown.active;
        case "recording":
            return ScreenRec.recording;
        case "message":
            return Notifs.flash !== null && !Flags.dnd;
        case "music":
            return Players.playing && Players.title.length > 0;
        }
        return false;
    }

    /** Walks up to the pill so a click can open a surface without the face wiring a signal. */
    function open(surface) {
        for (let p = act.parent; p; p = p.parent) {
            if (typeof p.requestSurface === "function") {
                p.requestSurface(surface);
                return;
            }
        }
    }

    function activate() {
        if (kind === "agent") {
            Agents.focus(Agents.top);
        } else if (kind === "recording") {
            open("recorder");
        } else if (kind === "message") {
            Notifs.flash = null;
            open("link");
        } else if (kind === "music") {
            open("media");
        }
    }

    property int recSeconds: 0
    Timer {
        interval: 1000
        running: act.kind === "recording" && act.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: act.recSeconds = Math.max(0, Math.floor((Date.now() - ScreenRec.startedAt) / 1000))
    }

    implicitWidth: kind.length > 0 ? row.implicitWidth : 0
    implicitHeight: 20 * s

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * act.s

        Rectangle {
            id: pulse
            anchors.verticalCenter: parent.verticalCenter
            visible: act.waits
            width: 7 * act.s
            height: width
            radius: width / 2
            color: Theme.vermLit
            SequentialAnimation on opacity {
                running: pulse.visible && !Motion.calm
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind === "recording"
            width: 7 * act.s
            height: width
            radius: width / 2
            color: Theme.danger
        }

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind.length > 0 && act.kind !== "recording" && !act.waits
            width: 14 * act.s
            height: width
            name: ({ timer: "stopwatch", message: "inbox", music: "music" })[act.kind] || "check"
            color: Theme.vermLit
            stroke: 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind !== "music"
            width: act.kind === "message" ? Math.min(implicitWidth, 110 * act.s) : implicitWidth
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: act.kind === "agent" ? Agents.project(Agents.top)
                : act.kind === "timer" ? Countdown.label
                : act.kind === "recording" ? Countdown.fmt(act.recSeconds)
                : act.kind === "message" && Notifs.flash ? Notifs.flash.app
                : ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14 * act.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.kind === "agent"
            text: act.waits ? "needs you" : "finished"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 14 * act.s
            font.weight: Font.Medium
        }

        Marquee {
            anchors.verticalCenter: parent.verticalCenter
            visible: act.scrolls
            width: Math.min(implicitWidth, (act.kind === "music" ? 180 : 170) * act.s)
            s: act.s
            auto: true
            active: act.visible && act.scrolls
            text: act.kind === "music" ? Players.title
                : act.kind === "message" && Notifs.flash ? Notifs.flash.summary
                : ""
            color: act.kind === "music" ? Theme.cream : Theme.textFaint
            pixelSize: 14 * act.s
            weight: act.kind === "music" ? Font.DemiBold : Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: act.kind.length > 0 && act.kind !== "timer"
        cursorShape: Qt.PointingHandCursor
        onClicked: act.activate()
    }
}
