pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Singletons"

/**
 * Media surface: a compact warm-lacquer now-playing card. A small shadowed album
 * cover sits beside a single-line title and artist, with stroked transport
 * controls and a ringed play/pause button. A hairline seam beneath traces
 * playback; its played edge is the dock point for the pill's living flame, which
 * crawls along the seam as the song advances. Driven by the active MPRIS player;
 * the pill body shows through as the warm background.
 */
Item {
    id: root

    property real s: 1
    property bool active: false
    signal requestClose()

    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return controllable ? controllable : list[0];
    }

    onPlayerChanged: console.log("[diag] Media.player ->",
        player ? (player.identity || player.dbusName || "unknown") : "none")

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property string title: hasPlayer && player.trackTitle ? player.trackTitle : "Nothing playing"
    readonly property string artist: {
        if (!hasPlayer)
            return "";
        if (player.trackArtists && player.trackArtists.length > 0)
            return player.trackArtists;
        return player.trackArtist ? player.trackArtist : "";
    }
    readonly property string artUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property bool hasArt: cover.status === Image.Ready && artUrl !== ""
        && cover.source.toString() === artUrl
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real playFrac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0
    property real dragFrac: 0
    property bool dragging: false
    readonly property real frac: dragging ? dragFrac : playFrac

    readonly property real seamHeadX: seamFill.mapToItem(root, seamFill.width, seamFill.height / 2).x
    readonly property real seamHeadY: seamFill.mapToItem(root, seamFill.width, seamFill.height / 2).y

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    Timer {
        interval: 500
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    ClippingRectangle {
        id: coverBox
        anchors.left: parent.left
        anchors.top: parent.top
        width: 50 * root.s
        height: 50 * root.s
        radius: Motion.rTile * root.s
        color: Theme.tileBg

        Image {
            id: cover
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.hasArt
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: parent.width * 0.4
            height: width
            name: "music"
            color: Theme.subtle
            visible: !root.hasArt
        }
    }

    Rectangle {
        anchors.fill: coverBox
        radius: coverBox.radius
        color: "transparent"
        z: -1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.6
            shadowVerticalOffset: 3 * root.s
        }
    }

    Item {
        id: textBlock
        anchors.left: coverBox.right
        anchors.leftMargin: 14 * root.s
        anchors.right: controls.left
        anchors.rightMargin: 12 * root.s
        anchors.top: coverBox.top
        anchors.bottom: coverBox.bottom

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 3 * root.s

            Marquee {
                id: titleText
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.title
                color: Theme.cream
                pixelSize: 14.5 * root.s
                weight: Font.Bold
                active: root.active
            }
            Marquee {
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.artist
                color: Theme.dim
                pixelSize: 11 * root.s
                active: root.active
                visible: text.length > 0
            }
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: coverBox.verticalCenter
        spacing: 12 * root.s

        Item {
            width: 17 * root.s
            height: 17 * root.s
            anchors.verticalCenter: parent.verticalCenter
            opacity: prevArea.enabled ? (prevArea.containsMouse ? 1 : 0.75) : 0.4
            Behavior on opacity { NumberAnimation { duration: 120 } }
            GlyphIcon {
                anchors.fill: parent
                name: "prev-s"
                stroke: 1.8
                color: Theme.cream
            }
            MouseArea {
                id: prevArea
                anchors.fill: parent
                anchors.margins: -7 * root.s
                hoverEnabled: true
                enabled: root.hasPlayer && root.player.canGoPrevious
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.previous();
            }
        }

        Item {
            width: 31 * root.s
            height: 31 * root.s
            anchors.verticalCenter: parent.verticalCenter
            opacity: ppArea.enabled ? (ppArea.containsMouse ? 1 : 0.75) : 0.4
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.5 * root.s
                border.color: Qt.alpha(Theme.vermLit, 0.8)

                GlyphIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.playing ? 0 : 1 * root.s
                    width: 13 * root.s
                    height: width
                    name: root.playing ? "pause-s" : "play-s"
                    stroke: 1.7
                    color: Theme.vermLit
                }
            }
            MouseArea {
                id: ppArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.hasPlayer && root.player.canTogglePlaying
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.togglePlaying();
            }
        }

        Item {
            width: 17 * root.s
            height: 17 * root.s
            anchors.verticalCenter: parent.verticalCenter
            opacity: nextArea.enabled ? (nextArea.containsMouse ? 1 : 0.75) : 0.4
            Behavior on opacity { NumberAnimation { duration: 120 } }
            GlyphIcon {
                anchors.fill: parent
                name: "next-s"
                stroke: 1.8
                color: Theme.cream
            }
            MouseArea {
                id: nextArea
                anchors.fill: parent
                anchors.margins: -7 * root.s
                hoverEnabled: true
                enabled: root.hasPlayer && root.player.canGoNext
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.next();
            }
        }
    }

    Item {
        id: progress
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 12 * root.s

        Text {
            id: tcur
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.positionSec)
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.features: { "tnum": 1 }
        }
        Text {
            id: ttot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.fmt(root.lengthSec)
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.features: { "tnum": 1 }
        }
        Rectangle {
            id: seam
            anchors.left: tcur.right
            anchors.leftMargin: 11 * root.s
            anchors.right: ttot.left
            anchors.rightMargin: 11 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 1.5 * root.s
            color: Theme.threadBg

            Rectangle {
                id: seamFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                property real targetW: parent.width * root.frac
                property real lastFrac: 0

                width: targetW
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.verm, 0.4) }
                    GradientStop { position: 1.0; color: Theme.vermLit }
                }

                Behavior on width {
                    enabled: Math.abs(root.frac - seamFill.lastFrac) < 0.02
                    NumberAnimation { duration: 500; easing.type: Easing.Linear }
                }
                onTargetWChanged: Qt.callLater(() => { seamFill.lastFrac = root.frac; })
            }

            Timer {
                id: dragWrite
                interval: 150
                repeat: true
                onTriggered: seekArea.commit()
            }

            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -8 * root.s
                enabled: root.hasPlayer && root.player.canSeek && root.lengthSec > 0
                cursorShape: Qt.PointingHandCursor
                function fracAt(mx) {
                    return Math.max(0, Math.min(1, (mx + 8 * root.s) / seam.width));
                }
                function commit() {
                    if (root.player)
                        root.player.position = root.dragFrac * root.lengthSec;
                }
                onClicked: (e) => {
                    root.dragFrac = fracAt(e.x);
                    commit();
                }
                onPressed: (e) => {
                    root.dragFrac = fracAt(e.x);
                    root.dragging = true;
                    dragWrite.restart();
                }
                onPositionChanged: (e) => { if (pressed) root.dragFrac = fracAt(e.x); }
                onReleased: {
                    dragWrite.stop();
                    commit();
                    root.dragging = false;
                }
            }
        }
    }
}
