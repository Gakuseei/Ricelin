pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "Singletons"

/**
 * 録 RECORD surface: drives gpu-screen-recorder through the ScreenRec singleton,
 * built as a flat washi "capture card". The header carries the kanji, label and
 * a status slot (Idle / pulsing dot + elapsed m:ss / Get ready). A tappable
 * config stage shows the recording spec and folds open an options drawer (Frame
 * rate / Quality MiniSegs and a Capture-cursor toggle). A full-width flame action
 * bar starts, counts down and stops the capture; two compact audio rows expose
 * the captured mic and desktop levels on flat-tick faders; a horizontal filmstrip
 * lists recent clips.
 *
 * The flow is chill: the user picks WHAT to record at leisure with nothing
 * recording yet, THEN a pre-roll countdown runs, THEN gsr records. Pressing while
 * idle opens an in-surface source chooser with two choices — Screen and Window /
 * Region. Screen resolves to a monitor (a sub-chooser of the connected screens
 * when more than one) via ScreenRec.prepareScreen; Window / Region feeds the
 * Hyprland client rectangles to slurp (prepareWindow) so a click snaps to a
 * window and a drag draws a freeform region, captured as a static rectangle.
 * Either resolves to ScreenRec.targetReady(token), at which point the
 * Flags.recordCountdown countdown runs (the bar fills over it, tap cancels) and
 * then gsr starts. Zero countdown starts at once; a cancelled pick aborts
 * cleanly. Pressing while recording stops and saves. Audio faders drive the
 * default Pipewire sink and source levels, matching what gsr captures via its
 * default_output / default_input aliases.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    implicitHeight: content.implicitHeight

    property string screenName: ""

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property int countdown: ScreenRec.countdown
    readonly property bool counting: ScreenRec.counting
    property int elapsed: 0

    property bool drawerOpen: false
    property bool chooserOpen: false
    property bool screenChooserOpen: false

    /**
     * Audio-fader keyboard focus index: 0 mic, 1 desktop, -1 none. Only an
     * enabled (toggled-on) fader accepts the focus; the host's hover and arrow
     * keys set it.
     */
    property int faderFocus: -1

    readonly property point recPoint: {
        void root.width;
        void root.height;
        return recDot.mapToItem(root, recDot.width / 2, recDot.height / 2);
    }

    ameForm: (open && !root.counting && !ScreenRec.recording) ? "dock" : "off"
    amePoint: recPoint

    readonly property string qualityLabel: {
        var q = ScreenRec.quality;
        return q.charAt(0).toUpperCase() + q.slice(1);
    }

    readonly property string stageTitle: ScreenRec.recording ? "Recording" : "Screen recorder"

    readonly property string stageSpec: ScreenRec.fps + " fps · " + root.qualityLabel

    function fmtTime(sec) {
        var m = Math.floor(sec / 60);
        var s = sec % 60;
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    function press() {
        if (ScreenRec.recording) {
            ScreenRec.stop();
            return;
        }
        if (counting) {
            ScreenRec.cancel();
            return;
        }
        if (chooserOpen) {
            chooserOpen = false;
            screenChooserOpen = false;
            return;
        }
        chooserOpen = true;
        screenChooserOpen = false;
    }

    /**
     * A source tile was picked in the chooser. Screen with several monitors opens
     * the monitor sub-chooser; otherwise each source kicks off its resolver
     * (which counts down once the target is ready), then the chooser closes.
     */
    function chooseSource(kind) {
        if (kind === "screen") {
            if (ScreenRec.monitors.length > 1) {
                screenChooserOpen = true;
                return;
            }
            ScreenRec.prepareScreen(root.screenName);
        } else if (kind === "window") {
            ScreenRec.prepareWindow();
        }
        chooserOpen = false;
        screenChooserOpen = false;
    }

    function pickMonitor(name) {
        chooserOpen = false;
        screenChooserOpen = false;
        ScreenRec.prepareScreen(name);
    }

    /**
     * Step the focused audio fader by `deltaPct`; returns true when an enabled
     * fader consumed it. Mirrors the mixer's stepFocused so the host can route
     * scroll-wheel and arrow keys here.
     */
    function stepFocused(deltaPct) {
        if (faderFocus === 0 && ScreenRec.micOn && root.source && root.source.audio) {
            root.source.audio.volume = Math.max(0, Math.min(1, root.source.audio.volume + deltaPct / 100));
            return true;
        }
        if (faderFocus === 1 && ScreenRec.desktopOn && root.sink && root.sink.audio) {
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + deltaPct / 100));
            return true;
        }
        return false;
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    onActiveChanged: {
        ScreenRec.recorderOpen = active;
        if (active) {
            ScreenRec.refreshRecent();
            faderFocus = -1;
            drawerOpen = false;
            chooserOpen = false;
            screenChooserOpen = false;
        } else {
            chooserOpen = false;
            screenChooserOpen = false;
        }
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: ScreenRec.recording
        onTriggered: root.elapsed += 1
    }

    Connections {
        target: ScreenRec
        function onRecordingChanged() {
            if (ScreenRec.recording) {
                root.elapsed = 0;
                root.drawerOpen = false;
                root.chooserOpen = false;
                root.screenChooserOpen = false;
            }
        }
    }

    /**
     * Mini-segmented choice control, copied from Settings: `options` is a list of
     * `{ label, value }`; the pill whose value equals `value` lights with a solid
     * card-top fill and cream text. Picking a pill emits `picked(value)`.
     */
    component MiniSeg: Rectangle {
        id: seg
        property var options: []
        property var value
        signal picked(var value)

        readonly property real pad: 2 * root.s

        width: pills.implicitWidth + 2 * pad
        height: pills.implicitHeight + 2 * pad
        radius: 9 * root.s
        color: "transparent"

        Row {
            id: pills
            anchors.centerIn: parent
            spacing: 2 * root.s

            Repeater {
                model: seg.options

                Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool current: seg.value === modelData.value

                    width: optLabel.implicitWidth + 18 * root.s
                    height: optLabel.implicitHeight + 12 * root.s
                    radius: 7 * root.s
                    color: opt.current ? Theme.cardTop : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        id: optLabel
                        anchors.centerIn: parent
                        text: opt.modelData.label
                        color: opt.current ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(opt.modelData.value)
                    }
                }
            }
        }
    }

    /**
     * One options-drawer line: a cream label on the left and a control pushed to
     * the right, capped by a top hairline on every row but the first.
     */
    component ORow: Item {
        id: orow
        property string name: ""
        property bool first: false
        default property alias control: controlSlot.data

        width: parent ? parent.width : 0
        height: 35 * root.s

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
            visible: !orow.first
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: orow.name
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Item {
            id: controlSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    /**
     * Compact audio row: a glyph, a label, a flat-tick fader and a percent
     * readout. The fader dims and stops accepting input when its audio is off.
     */
    component AudioRow: Item {
        id: arow
        property string glyph: ""
        property string name: ""
        property bool on: false
        property int faderIndex: -1
        property real level: 0.5
        signal toggled()
        signal faderMoved(real v)

        width: parent ? parent.width : 0
        height: 27 * root.s

        GlyphIcon {
            id: rowGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            name: arow.glyph
            color: arow.on ? Theme.vermLit : Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: rowName
            anchors.left: rowGlyph.right
            anchors.leftMargin: 11 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 76 * root.s
            text: arow.name
            color: arow.on ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        HFader {
            id: fader
            anchors.left: rowName.right
            anchors.leftMargin: 4 * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            on: arow.on
            value: arow.level
            focused: arow.on && root.faderFocus === arow.faderIndex
            onMoved: (v) => arow.faderMoved(v)
            onFocusRequested: root.faderFocus = arow.faderIndex

            HoverHandler {
                onHoveredChanged: if (hovered && arow.on) root.faderFocus = arow.faderIndex
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                enabled: arow.on
                property real acc: 0
                onWheel: (event) => {
                    root.faderFocus = arow.faderIndex;
                    acc += event.angleDelta.y / 120;
                    const notches = Math.trunc(acc);
                    if (notches !== 0) {
                        root.stepFocused(notches * 5);
                        acc -= notches;
                    }
                    event.accepted = true;
                }
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "録"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RECORD"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ScreenRec.recording
                    width: 7 * root.s
                    height: 7 * root.s
                    radius: width / 2
                    color: Theme.verm
                    SequentialAnimation on opacity {
                        running: ScreenRec.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenRec.recording ? root.fmtTime(root.elapsed)
                        : (root.counting ? "GET READY" : "IDLE")
                    color: ScreenRec.recording ? Theme.vermLit : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                    font.features: { "tnum": 1 }
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        Item {
            id: stageGroup
            width: parent.width
            height: stage.height + drawer.height

            Rectangle {
                id: stage
                property bool pressActive: false
                width: parent.width
                height: 76 * root.s
                radius: 13 * root.s
                color: Theme.cardBot
                transformOrigin: Item.Center
                scale: pressActive ? 0.984 : 1
                Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius + 1
                    visible: root.drawerOpen
                    color: Theme.cardBot
                }

                Repeater {
                    model: [
                        { hx: false, vy: false },
                        { hx: true, vy: false },
                        { hx: false, vy: true },
                        { hx: true, vy: true }
                    ]

                    Item {
                        id: corner
                        required property var modelData
                        readonly property color arm: Qt.alpha(Theme.vermLit, 0.5)
                        width: 14 * root.s
                        height: 14 * root.s
                        opacity: root.counting || ScreenRec.recording
                            || (modelData.vy && root.drawerOpen) ? 0 : 1
                        x: modelData.hx ? stage.width - width - 11 * root.s : 11 * root.s
                        y: modelData.vy ? stage.height - height - 11 * root.s : 11 * root.s
                        rotation: modelData.hx ? (modelData.vy ? 180 : 90) : (modelData.vy ? 270 : 0)
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: corner.arm
                                strokeWidth: 2 * root.s
                                fillColor: "transparent"
                                capStyle: ShapePath.FlatCap
                                joinStyle: ShapePath.RoundJoin
                                startX: 1 * root.s
                                startY: 13 * root.s
                                PathLine { x: 1 * root.s; y: 5.5 * root.s }
                                PathQuad { controlX: 1 * root.s; controlY: 1 * root.s; x: 5.5 * root.s; y: 1 * root.s }
                                PathLine { x: 13 * root.s; y: 1 * root.s }
                            }
                        }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 22 * root.s
                    anchors.right: chevron.left
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * root.s

                    Text {
                        width: parent.width
                        text: root.stageTitle
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Row {
                        width: parent.width
                        spacing: 6 * root.s

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5 * root.s
                            height: 5 * root.s
                            radius: width / 2
                            color: ScreenRec.recording ? Theme.verm : Theme.vermDim
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.stageSpec
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    visible: ScreenRec.recording
                    anchors.right: parent.right
                    anchors.rightMargin: 16 * root.s
                    anchors.top: parent.top
                    anchors.topMargin: 13 * root.s
                    spacing: 5 * root.s

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6 * root.s
                        height: 6 * root.s
                        radius: width / 2
                        color: Theme.verm
                    }
                    Text {
                        text: "REC"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1.2 * root.s
                    }
                }

                GlyphIcon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "chevron-down"
                    color: root.drawerOpen ? Theme.vermLit : Theme.faint
                    stroke: 2.2
                    rotation: root.drawerOpen ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: stage.pressActive = true
                    onReleased: stage.pressActive = false
                    onCanceled: stage.pressActive = false
                    onClicked: if (!ScreenRec.recording && !root.counting && !root.chooserOpen)
                        root.drawerOpen = !root.drawerOpen
                }
            }

            Item {
                id: drawer
                anchors.top: stage.bottom
                width: parent.width
                height: root.drawerOpen ? drawerCol.implicitHeight : 0
                clip: true
                visible: height > 0
                Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.fill: parent
                    radius: 13 * root.s
                    color: Theme.cardBot
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 13 * root.s + 1
                    color: Theme.cardBot
                }

                Column {
                    id: drawerCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18 * root.s
                    anchors.rightMargin: 16 * root.s
                    topPadding: 2 * root.s
                    bottomPadding: 10 * root.s

                    ORow {
                        name: "Frame rate"
                        first: true
                        MiniSeg {
                            options: [
                                { label: "30", value: 30 },
                                { label: "60", value: 60 },
                                { label: "120", value: 120 },
                                { label: "144", value: 144 }
                            ]
                            value: ScreenRec.fps
                            onPicked: (v) => ScreenRec.fps = v
                        }
                    }
                    ORow {
                        name: "Quality"
                        MiniSeg {
                            options: [
                                { label: "Med", value: "medium" },
                                { label: "High", value: "high" },
                                { label: "Ultra", value: "ultra" },
                                { label: "Loss", value: "lossless" }
                            ]
                            value: ScreenRec.quality
                            onPicked: (v) => ScreenRec.quality = v
                        }
                    }
                    ORow {
                        name: "Capture cursor"
                        LinkToggle {
                            s: root.s
                            on: ScreenRec.captureCursor
                            onToggled: ScreenRec.captureCursor = !ScreenRec.captureCursor
                        }
                    }
                    ORow {
                        name: "Countdown"
                        MiniSeg {
                            options: [
                                { label: "Off", value: 0 },
                                { label: "3s", value: 3 },
                                { label: "5s", value: 5 },
                                { label: "10s", value: 10 }
                            ]
                            value: Flags.recordCountdown
                            onPicked: (v) => Flags.recordCountdown = v
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        Item {
            id: actionGroup
            width: parent.width
            height: 44 * root.s

            Rectangle {
                id: actionBar
                anchors.fill: parent
                radius: 14 * root.s
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ScreenRec.recording ? Qt.alpha(Theme.verm, 0.34) : Qt.alpha(Theme.verm, 0.2) }
                    GradientStop { position: 1.0; color: ScreenRec.recording ? Qt.alpha(Theme.verm, 0.16) : Qt.alpha(Theme.flameGlow, 0.09) }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: actionBar.radius
                    color: "transparent"

                    Rectangle {
                        id: cdFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        visible: root.counting
                        width: parent.width * (root.counting && Flags.recordCountdown > 0
                            ? (Flags.recordCountdown - root.countdown + 1) / Flags.recordCountdown : 0)
                        color: Qt.alpha(Theme.vermLit, 0.18)
                        Behavior on width { NumberAnimation { duration: 950; easing.type: Easing.Linear } }
                    }
                }

                Rectangle {
                    id: recDot
                    anchors.left: parent.left
                    anchors.leftMargin: 18 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.counting && !ScreenRec.recording
                    width: 17 * root.s
                    height: 17 * root.s
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.vermLit }
                        GradientStop { position: 1.0; color: Theme.vermDeep }
                    }
                }

                Rectangle {
                    id: stopSquare
                    anchors.left: parent.left
                    anchors.leftMargin: 18 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ScreenRec.recording
                    width: 15 * root.s
                    height: 15 * root.s
                    radius: 4 * root.s
                    color: Theme.vermLit
                    SequentialAnimation on scale {
                        running: ScreenRec.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.08; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    id: cdNumber
                    anchors.left: parent.left
                    anchors.leftMargin: 20 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.counting
                    text: root.countdown
                    color: Theme.flameGlow
                    font.family: Theme.font
                    font.pixelSize: 24 * root.s
                    font.weight: Font.ExtraBold
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.counting ? 46 * root.s : 47 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenRec.recording ? "Stop recording"
                        : (root.counting ? "Starting…" : "Start recording")
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5 * root.s
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 18 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.counting ? "tap to cancel" : "tap"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.press()
                }
            }

            Rectangle {
                id: chooser
                anchors.fill: parent
                visible: root.chooserOpen
                radius: 14 * root.s
                color: Theme.cardBot
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.chooserOpen = false
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 6 * root.s
                    spacing: 6 * root.s

                    Repeater {
                        model: [
                            { kind: "screen", label: "Screen", glyph: "monitor" },
                            { kind: "window", label: "Window / Region", glyph: "video" }
                        ]

                        Rectangle {
                            id: srcTile
                            required property var modelData
                            width: (chooser.width - 12 * root.s - 6 * root.s) / 2
                            height: parent.height
                            radius: 9 * root.s
                            color: srcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                            border.width: 1
                            border.color: srcArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8 * root.s

                                GlyphIcon {
                                    width: 16 * root.s
                                    height: 16 * root.s
                                    name: srcTile.modelData.glyph
                                    color: srcArea.containsMouse ? Theme.vermLit : Theme.iconDim
                                    stroke: 1.7
                                }
                                Text {
                                    height: 16 * root.s
                                    verticalAlignment: Text.AlignVCenter
                                    text: srcTile.modelData.label
                                    color: srcArea.containsMouse ? Theme.cream : Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 11 * root.s
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: srcArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chooseSource(srcTile.modelData.kind)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: screenChooser
                anchors.fill: parent
                visible: root.screenChooserOpen
                radius: 14 * root.s
                color: Theme.cardBot
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.screenChooserOpen = false
                }

                ListView {
                    id: monList
                    anchors.fill: parent
                    anchors.margins: 6 * root.s
                    anchors.rightMargin: 22 * root.s
                    orientation: ListView.Horizontal
                    spacing: 6 * root.s
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScreenRec.monitors

                    delegate: Rectangle {
                        id: monTile
                        required property var modelData
                        width: 152 * root.s
                        height: monList.height
                        radius: 9 * root.s
                        color: monArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                        border.width: 1
                        border.color: monArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.5) : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2 * root.s

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monTile.modelData.name
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: monTile.modelData.w + " × " + monTile.modelData.h
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 9.5 * root.s
                                font.features: { "tnum": 1 }
                            }
                        }

                        MouseArea {
                            id: monArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickMonitor(monTile.modelData.name)
                        }
                    }
                }

                WheelScroller {
                    flick: monList
                    s: root.s
                    anchors.fill: monList
                }

                GlyphIcon {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 7 * root.s
                    width: 12 * root.s
                    height: 12 * root.s
                    name: "chevron-left"
                    color: backArea.containsMouse ? Theme.cream : Theme.faint
                    stroke: 2

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        anchors.margins: -7 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.screenChooserOpen = false;
                            root.chooserOpen = true;
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 11 * root.s }

        AudioRow {
            glyph: "mic"
            name: "Microphone"
            on: ScreenRec.micOn
            faderIndex: 0
            level: root.source && root.source.audio ? root.source.audio.volume : 0
            onFaderMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }

            MouseArea {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 80 * root.s
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: ScreenRec.micOn = !ScreenRec.micOn
            }
        }

        AudioRow {
            glyph: "speaker"
            name: "Desktop"
            on: ScreenRec.desktopOn
            faderIndex: 1
            level: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            onFaderMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }

            MouseArea {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 80 * root.s
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: ScreenRec.desktopOn = !ScreenRec.desktopOn
            }
        }

        Item { width: 1; height: 11 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 11 * root.s }

        /**
         * Save-location row: a tracked "SAVE TO" label, the output directory
         * collapsed to `~` and elided to fit, and Change / Open affordances that
         * drive the native picker and file manager.
         */
        Item {
            id: pathRow
            width: parent.width
            height: 18 * root.s

            readonly property string shownDir: {
                var d = ScreenRec.outDir;
                var h = ScreenRec.home;
                return h.length > 0 && d.indexOf(h) === 0 ? "~" + d.slice(h.length) : d;
            }

            Text {
                id: pathLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "SAVE TO"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2 * root.s
            }

            Item {
                id: pathActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: changeTxt.width + 9 * root.s + openTxt.width

                Text {
                    id: changeTxt
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CHANGE"
                    color: changeArea.containsMouse ? Theme.flameGlow : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s

                    MouseArea {
                        id: changeArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRec.pickDir()
                    }
                }
                Text {
                    id: openTxt
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OPEN"
                    color: openArea.containsMouse ? Theme.flameGlow : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s

                    MouseArea {
                        id: openArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRec.openDir()
                    }
                }
            }

            Text {
                id: pathText
                anchors.left: pathLabel.right
                anchors.leftMargin: 10 * root.s
                anchors.right: pathActions.left
                anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: pathRow.shownDir
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }

        Item { width: 1; height: 11 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 12 * root.s }

        Item {
            width: parent.width
            height: 16 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s

                Text {
                    visible: Flags.showGlyphs
                    height: 16 * root.s
                    verticalAlignment: Text.AlignVCenter
                    text: "録"
                    color: Theme.subtle
                    font.family: Theme.fontJp
                    font.pixelSize: 11 * root.s
                }
                Text {
                    height: 16 * root.s
                    verticalAlignment: Text.AlignVCenter
                    text: "RECENT · " + ScreenRec.recentCount
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                }
            }

            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: clearTxt.width + (Flags.showGlyphs ? clearKanji.width + 5 * root.s : 0)
                visible: ScreenRec.recentCount > 0

                Text {
                    id: clearKanji
                    anchors.right: clearTxt.left
                    anchors.rightMargin: 5 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "払"
                    color: clearArea.containsMouse ? Theme.flameGlow : Theme.vermDeep
                    font.family: Theme.fontJp
                    font.pixelSize: 11 * root.s
                }
                Text {
                    id: clearTxt
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLEAR"
                    color: clearArea.containsMouse ? Theme.flameGlow : Theme.vermDeep
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ScreenRec.clearRecent()
                }
            }
        }

        Item { width: 1; height: 9 * root.s }

        Item {
            width: parent.width
            height: 64 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: ScreenRec.recentCount === 0
                text: "No recordings yet"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
            }

            ListView {
                id: filmstrip
                anchors.fill: parent
                visible: ScreenRec.recentCount > 0
                orientation: ListView.Horizontal
                clip: true
                spacing: 9 * root.s
                boundsBehavior: Flickable.StopAtBounds
                model: ScreenRec.recent

                delegate: Item {
                    id: frame
                    required property int index
                    required property var modelData

                    /**
                     * The clip name is `recording_YYYY-MM-DD_HH-MM-SS`; only the
                     * day and time matter beside the size, so it is shown as
                     * `MM-DD HH:MM` to leave room for the size on the same line.
                     */
                    readonly property string stamp: {
                        var m = /_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/.exec(frame.modelData.name);
                        return m ? m[2] + "-" + m[3] + " " + m[4] + ":" + m[5]
                                 : frame.modelData.name.replace("recording_", "").replace(".mp4", "");
                    }
                    readonly property bool coverReady: cover.status === Image.Ready && cover.source !== ""

                    width: 108 * root.s
                    height: filmstrip.height

                    ClippingRectangle {
                        id: thumb
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 48 * root.s
                        radius: 9 * root.s
                        color: Theme.tileBg

                        Rectangle {
                            anchors.fill: parent
                            visible: !frame.coverReady
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.cardTop }
                                GradientStop { position: 1.0; color: Theme.tileBg }
                            }
                        }

                        Image {
                            id: cover
                            anchors.fill: parent
                            source: frame.modelData.thumb ? "file://" + frame.modelData.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: 216 * root.s
                            sourceSize.height: 96 * root.s
                        }

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 14 * root.s
                            height: 14 * root.s
                            visible: !frame.coverReady
                            name: "play"
                            color: frameArea.containsMouse ? Theme.cream : Theme.iconDim
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: width / 2
                            visible: frame.coverReady
                            color: Qt.rgba(0, 0, 0, 0.34)
                            opacity: frameArea.containsMouse ? 1 : 0.7
                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 11 * root.s
                                height: 11 * root.s
                                name: "play"
                                color: Theme.cream
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: thumb
                        radius: thumb.radius
                        color: "transparent"
                        border.width: 1.5
                        border.color: frame.index === 0 ? Qt.alpha(Theme.vermLit, 0.4)
                            : (frameArea.containsMouse ? Theme.vermDim : Theme.border)
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    }

                    Item {
                        id: meta
                        anchors.top: thumb.bottom
                        anchors.topMargin: 5 * root.s
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: stampTxt.height

                        Text {
                            id: stampTxt
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: sizeTxt.left
                            anchors.rightMargin: 4 * root.s
                            text: frame.stamp
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            id: sizeTxt
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: frame.modelData.sizeLabel
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }

                    MouseArea {
                        id: frameArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ScreenRec.openFile(frame.modelData.path)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (event) => {
                    var max = Math.max(0, filmstrip.contentWidth - filmstrip.width);
                    filmstrip.contentX = Math.max(0, Math.min(max, filmstrip.contentX - event.angleDelta.y / 120 * 48 * root.s));
                    event.accepted = true;
                }
            }
        }
    }
}
