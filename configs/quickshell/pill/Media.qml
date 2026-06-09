pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Singletons"

/**
 * Media surface: the playback progress is traced as a glowing terracotta arc
 * along the pill's own rounded edge — the same edge language as the rest comet —
 * over a warm lacquer interior holding a sharp album cover, the track text and
 * transport controls. Driven by the active MPRIS player.
 */
Item {
    id: root

    property real s: 1
    property bool active: false
    property real radius: 22 * s
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
    readonly property bool hasArt: cover.status === Image.Ready && artUrl != ""
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real frac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    Timer {
        interval: 1000
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    Shape {
        id: edge
        anchors.fill: parent
        anchors.margins: 1.6 * root.s
        preferredRendererType: Shape.CurveRenderer
        visible: root.frac > 0.001

        readonly property real cr: Math.max(2, root.radius - 1.6 * root.s)
        readonly property real sw: 2.6 * root.s
        readonly property real perim: 2 * (width - 2 * cr) + 2 * (height - 2 * cr) + 2 * Math.PI * cr

        ShapePath {
            strokeColor: Theme.vermLit
            strokeWidth: edge.sw
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            strokeStyle: ShapePath.DashLine
            dashPattern: [root.frac * edge.perim / edge.sw, (1 - root.frac) * edge.perim / edge.sw + 0.001]
            dashOffset: 0

            startX: edge.width / 2
            startY: 0
            PathLine { x: edge.width - edge.cr; y: 0 }
            PathArc { x: edge.width; y: edge.cr; radiusX: edge.cr; radiusY: edge.cr }
            PathLine { x: edge.width; y: edge.height - edge.cr }
            PathArc { x: edge.width - edge.cr; y: edge.height; radiusX: edge.cr; radiusY: edge.cr }
            PathLine { x: edge.cr; y: edge.height }
            PathArc { x: 0; y: edge.height - edge.cr; radiusX: edge.cr; radiusY: edge.cr }
            PathLine { x: 0; y: edge.cr }
            PathArc { x: edge.cr; y: 0; radiusX: edge.cr; radiusY: edge.cr }
            PathLine { x: edge.width / 2; y: 0 }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.5
            blurMax: 12
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 15 * root.s

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: height
            height: parent.height
            radius: 12 * root.s
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
                width: parent.width * 0.34
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
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.6
                shadowVerticalOffset: 2 * root.s
            }
        }

        Item {
            anchors.left: coverBox.right
            anchors.leftMargin: 16 * root.s
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Column {
                id: meta
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 3 * root.s

                Row {
                    spacing: 7 * root.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "奏"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                    }
                    Text {
                        text: root.playing ? "NOW PLAYING" : "PAUSED"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.5 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    topPadding: 4 * root.s
                    text: root.title
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 16 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.artist
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: 18 * root.s

                Item {
                    width: 21 * root.s
                    height: 21 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    GlyphIcon {
                        anchors.fill: parent
                        name: "prev"
                        color: prevArea.containsMouse ? Theme.vermLit : (prevArea.enabled ? Theme.cream : Theme.disabled)
                    }
                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        hoverEnabled: true
                        enabled: root.hasPlayer && root.player.canGoPrevious
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.previous();
                    }
                }

                Rectangle {
                    width: 33 * root.s
                    height: 33 * root.s
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: ppArea.containsMouse ? Theme.vermLit : Theme.verm
                    Behavior on color { ColorAnimation { duration: 120 } }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 15 * root.s
                        height: width
                        name: root.playing ? "pause" : "play"
                        color: Theme.onAccent
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
                    width: 21 * root.s
                    height: 21 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    GlyphIcon {
                        anchors.fill: parent
                        name: "next"
                        color: nextArea.containsMouse ? Theme.vermLit : (nextArea.enabled ? Theme.cream : Theme.disabled)
                    }
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        hoverEnabled: true
                        enabled: root.hasPlayer && root.player.canGoNext
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.next();
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4 * root.s
                text: root.fmt(root.positionSec) + "  /  " + root.fmt(root.lengthSec)
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
            }
        }
    }
}
