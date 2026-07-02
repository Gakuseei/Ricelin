pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "Singletons"

/**
 * Now-playing card. Album art bleeds edge-to-edge on the left, faded into the
 * card; a blurred copy glows through a near-opaque warm wash behind everything.
 * Right of the cover: title, artist, a dim source/time line, the play/pause
 * seal (奏/休) flanked by 前/次 skips. Playback runs as a brush stroke along the
 * bottom, its painted head the dock for the pill's soul bead. All now-playing
 * data comes from [[Players]]; when two or more players run, the source token
 * glows into a bubble that opens a picker.
 */
PillSurface {
    id: root

    readonly property var player: Players.active
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: Players.playing
    readonly property string title: Players.has && Players.title ? Players.title : "Nothing playing"
    readonly property string artist: Players.artist
    readonly property bool live: Players.live
    readonly property string serviceLabel: Players.serviceLabel

    /**
     * Art only decodes while this monitor's surface is open, keyed on the track
     * so a browser reusing one file path still reloads on a new song. The shared
     * url means every monitor shows the same cover, never a stale neighbour.
     */
    readonly property string coverSource: {
        if (!root.active)
            return "";
        var u = Players.artUrl;
        if (!u)
            return "";
        return u.indexOf("file:") === 0 ? u + "#" + Players.trackKey : u;
    }
    /** Latched on first decode so the fallback glyph doesn't flash back while a track change reloads behind the retained cover. */
    property bool everReady: false
    onCoverSourceChanged: if (coverSource.length === 0) everReady = false

    readonly property real lengthSec: Players.lengthSec
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real playFrac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0
    property real dragFrac: 0
    property bool dragging: false
    readonly property real frac: dragging ? dragFrac : playFrac

    /** Source picker is open; only reachable when more than one player runs. */
    property bool picking: false
    readonly property bool canPick: Players.pickable.length > 1
    onActiveChanged: if (!active) picking = false
    onCanPickChanged: if (!canPick) picking = false
    onPickingChanged: if (picking) pickFlick.contentX = 0

    readonly property real textX: 134 * s
    readonly property real edgePad: 18 * s
    readonly property color washMid: mix(Theme.cardTop, Theme.cardBot, 0.5)
    property real sealPulse: 0

    readonly property point seamHead: {
        void root.width;
        void root.height;
        void root.frac;
        void stroke.x;
        void stroke.width;
        return stroke.mapToItem(root, stroke.headX, stroke.headY);
    }
    readonly property real seamHeadX: seamHead.x
    readonly property real seamHeadY: seamHead.y

    ameForm: "seam"
    amePoint: Qt.point(seamHeadX, seamHeadY)

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    onTitleChanged: if (playing && active) pulseAnim.restart()

    Timer {
        interval: 500
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "sealPulse"; to: 1; duration: Motion.fast; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "sealPulse"; to: 0; duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    component KanjiSkip: Item {
        id: skip

        property bool can: false
        property string kanjiText: ""
        property string icon: ""
        signal activated()

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Flags.showGlyphs ? kanjiLabel.implicitWidth : 15 * root.s
        implicitHeight: Flags.showGlyphs ? kanjiLabel.implicitHeight : 15 * root.s
        opacity: skip.can ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Text {
            id: kanjiLabel
            visible: Flags.showGlyphs
            anchors.centerIn: parent
            text: skip.kanjiText
            font.family: Theme.fontJp
            font.pixelSize: 13 * root.s
            color: skipArea.containsMouse ? Theme.cream : Theme.dim
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        GlyphIcon {
            visible: !Flags.showGlyphs
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: skip.icon
            color: skipArea.containsMouse ? Theme.cream : Theme.dim
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: skipArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            enabled: skip.can
            cursorShape: Qt.PointingHandCursor
            onClicked: skip.activated()
        }
    }

    /** Round album swatch that tags a source, falls back to a warm tile. */
    component ArtDot: ClippingRectangle {
        id: dot
        property string url: ""
        radius: width / 2
        color: Theme.tileBg
        Image {
            anchors.fill: parent
            source: dot.url
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22 * root.s
        color: "transparent"

        Image {
            id: bleedSrc
            anchors.fill: parent
            source: root.coverSource
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            retainWhileLoading: true
            cache: String(source).indexOf("file:") !== 0
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: bleedSrc
            scale: 1.12
            visible: root.active && bleedSrc.status === Image.Ready
            blurEnabled: true
            blur: 0.95
            blurMax: 64
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, 0.88) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, 0.93) }
            }
        }

        Item {
            id: coverBox
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 118 * root.s
            clip: true

            Rectangle {
                anchors.fill: parent
                color: Theme.tileBg
                visible: !root.everReady
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.coverSource
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                retainWhileLoading: true
                cache: String(source).indexOf("file:") !== 0
                onStatusChanged: if (status === Image.Ready) root.everReady = true
            }

            GlyphIcon {
                anchors.centerIn: parent
                width: 40 * root.s
                height: width
                name: "music"
                color: Theme.subtle
                visible: !root.everReady
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 62 * root.s
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 56 * root.s
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(root.washMid, 0) }
                GradientStop { position: 0.7; color: Qt.alpha(root.washMid, 0.8) }
                GradientStop { position: 1.0; color: root.washMid }
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.top: parent.top
        anchors.topMargin: 24 * root.s
        spacing: 3 * root.s

        Marquee {
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.title
            color: Theme.cream
            pixelSize: 17 * root.s
            weight: Font.DemiBold
            active: root.active
        }
        Marquee {
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.artist
            color: Theme.dim
            pixelSize: 11.5 * root.s
            active: root.active
            visible: text.length > 0
        }
    }

    Item {
        id: srcLine
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: root.picking ? parent.right : transport.left
        anchors.rightMargin: root.picking ? root.edgePad : 10 * root.s
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36 * root.s
        height: 34 * root.s

        readonly property string tail: root.live
            ? " - Live"
            : " / " + root.fmt(root.dragging ? root.dragFrac * root.lengthSec : root.positionSec)
                + " - " + root.fmt(root.lengthSec)

        Item {
            id: infoRow
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.picking ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            Text {
                id: plainSource
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.canPick && root.serviceLabel.length > 0
                text: root.serviceLabel
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
            }

            Rectangle {
                id: srcBubble
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.canPick
                height: 18 * root.s
                width: bubbleRow.width + 14 * root.s
                radius: height / 2
                color: Qt.alpha(Theme.verm, 0.16)
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, 0.45 + 0.35 * glow)

                property real glow: 0
                SequentialAnimation on glow {
                    running: srcBubble.visible && !root.picking
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 1300; easing.type: Easing.InOutSine }
                }

                Row {
                    id: bubbleRow
                    anchors.centerIn: parent
                    spacing: 5 * root.s
                    ArtDot {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s
                        height: 12 * root.s
                        url: Players.artUrlFor(root.player)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.serviceLabel
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▾"
                        color: Theme.vermLit
                        font.pixelSize: 8 * root.s
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picking = true
                }
            }

            Text {
                anchors.left: root.canPick ? srcBubble.right : plainSource.right
                anchors.leftMargin: 3 * root.s
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: srcLine.tail
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
            }
        }

        Flickable {
            id: pickFlick
            anchors.fill: parent
            clip: true
            visible: opacity > 0.01
            opacity: root.picking ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            contentWidth: pickRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    var step = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x;
                    var max = Math.max(0, pickFlick.contentWidth - pickFlick.width);
                    pickFlick.contentX = Math.max(0, Math.min(max, pickFlick.contentX - step));
                }
            }

            Row {
                id: pickRow
                height: pickFlick.height
                spacing: 7 * root.s

                Repeater {
                    model: root.picking ? Players.pickable : []
                    delegate: Rectangle {
                        id: bub
                        required property var modelData
                        readonly property bool isActive: modelData === Players.active
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32 * root.s
                        width: bubInner.width + 18 * root.s
                        radius: 11 * root.s
                        color: isActive ? Qt.alpha(Theme.verm, 0.2) : Qt.alpha(Theme.cream, 0.045)
                        border.width: 1
                        border.color: isActive ? Theme.vermLit : Qt.alpha(Theme.cream, 0.12)

                        Row {
                            id: bubInner
                            anchors.centerIn: parent
                            spacing: 7 * root.s
                            ArtDot {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16 * root.s
                                height: 16 * root.s
                                url: Players.artUrlFor(bub.modelData)
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Text {
                                    text: Players.labelOf(bub.modelData)
                                    color: bub.isActive ? Theme.bright : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 11 * root.s
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: Players.nowPlayingFor(bub.modelData)
                                    color: bub.isActive ? Theme.subtle : Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 8.5 * root.s
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 150 * root.s)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Players.select(bub.modelData);
                                root.picking = false;
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        id: transport
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38 * root.s
        spacing: 14 * root.s
        opacity: root.picking ? 0 : 1
        enabled: !root.picking
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        KanjiSkip {
            kanjiText: "前"
            icon: "prev"
            can: root.hasPlayer && root.player.canGoPrevious
            onActivated: if (root.player) root.player.previous()
        }

        Rectangle {
            id: seal
            anchors.verticalCenter: parent.verticalCenter
            width: 30 * root.s
            height: 30 * root.s
            radius: 7 * root.s
            rotation: -1.5
            scale: 1 + 0.08 * root.sealPulse

            property real sat: root.playing ? 1 : 0
            Behavior on sat { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

            opacity: (sealArea.enabled ? 1 : 0.4) * (0.75 + 0.25 * sat)
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            border.width: 1
            border.color: Qt.alpha(Theme.vermLit, 0.4 + 0.4 * root.sealPulse)
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.mix(Theme.verm, Theme.tileBg, 0.55 - 0.27 * seal.sat) }
                GradientStop { position: 1.0; color: root.mix(Theme.vermDeep, Theme.tileBg, 0.55 - 0.27 * seal.sat) }
            }

            Text {
                visible: Flags.showGlyphs
                anchors.centerIn: parent
                text: root.playing ? "奏" : "休"
                color: Theme.bright
                font.family: Theme.fontJp
                font.pixelSize: 16 * root.s
                font.weight: Font.DemiBold
            }

            GlyphIcon {
                visible: !Flags.showGlyphs
                anchors.centerIn: parent
                width: 15 * root.s
                height: 15 * root.s
                name: root.playing ? "pause" : "play"
                color: Theme.bright
            }

            MouseArea {
                id: sealArea
                anchors.fill: parent
                anchors.margins: -4 * root.s
                hoverEnabled: true
                enabled: root.hasPlayer && root.player.canTogglePlaying
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.player) root.player.togglePlaying()
            }
        }

        KanjiSkip {
            kanjiText: "次"
            icon: "next"
            can: root.hasPlayer && root.player.canGoNext
            onActivated: if (root.player) root.player.next()
        }
    }

    Canvas {
        id: stroke
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        anchors.right: parent.right
        anchors.rightMargin: root.edgePad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10 * root.s
        height: 18 * root.s

        readonly property real inset: 3 * root.s
        readonly property real usable: Math.max(1, width - 2 * inset)
        property real targetF: root.frac
        property real lastFrac: 0
        property real drawF: targetF
        readonly property real headX: inset + drawF * usable
        readonly property real headY: waveY(drawF)

        Behavior on drawF {
            enabled: Math.abs(root.frac - stroke.lastFrac) < 0.02
            NumberAnimation { duration: Math.round(500 * Motion.mult); easing.type: Easing.Linear }
        }
        onTargetFChanged: Qt.callLater(() => { stroke.lastFrac = root.frac; })

        onDrawFChanged: requestPaint()
        onWidthChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        function waveY(u) {
            return height / 2 - 2.6 * Math.sin(3 * Math.PI * u) * Math.exp(-2.5 * u) * root.s;
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 0 || height <= 0)
                return;
            const n = 48;
            ctx.strokeStyle = Theme.border;
            ctx.lineWidth = 2.5 * root.s;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(inset, waveY(0));
            for (let i = 1; i <= n; i++)
                ctx.lineTo(inset + (i / n) * usable, waveY(i / n));
            ctx.stroke();

            if (drawF <= 0.002)
                return;
            const hTail = 2.5 * root.s;
            const hHead = 1.75 * root.s;
            const m = Math.max(2, Math.ceil(n * drawF));
            ctx.fillStyle = Theme.verm;
            ctx.beginPath();
            ctx.arc(inset, waveY(0), hTail, Math.PI / 2, 3 * Math.PI / 2);
            for (let i = 0; i <= m; i++) {
                const u = (i / m) * drawF;
                ctx.lineTo(inset + u * usable, waveY(u) - (hTail + (hHead - hTail) * (i / m)));
            }
            ctx.arc(headX, headY, hHead, -Math.PI / 2, Math.PI / 2);
            for (let i = m; i >= 0; i--) {
                const u = (i / m) * drawF;
                ctx.lineTo(inset + u * usable, waveY(u) + (hTail + (hHead - hTail) * (i / m)));
            }
            ctx.closePath();
            ctx.fill();
        }

        MouseArea {
            id: seekArea
            anchors.fill: parent
            anchors.margins: -8 * root.s
            enabled: root.hasPlayer && root.player.canSeek && root.player.positionSupported && root.lengthSec > 0 && !root.live
            cursorShape: Qt.PointingHandCursor
            function fracAt(mx) {
                return Math.max(0, Math.min(1, (mx - 8 * root.s - stroke.inset) / stroke.usable));
            }
            onPressed: (e) => {
                root.dragFrac = fracAt(e.x);
                root.dragging = true;
            }
            onPositionChanged: (e) => { if (pressed) root.dragFrac = fracAt(e.x); }
            onReleased: {
                if (root.player)
                    root.player.position = root.dragFrac * root.lengthSec;
                root.dragging = false;
            }
        }
    }
}
