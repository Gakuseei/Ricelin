pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Widgets
import "Singletons"

/**
 * 録 Record: pick a source at leisure, a countdown runs, then gpu-screen-recorder captures; a second click stops and saves.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight

    readonly property var sink: Sound.sink
    readonly property var source: Sound.source

    readonly property int countdown: ScreenRec.countdown
    readonly property bool counting: ScreenRec.counting
    property int elapsed: 0

    property bool drawerOpen: false
    property bool chooserOpen: false
    property bool screenChooserOpen: false

    /**
     * Audio fader with keyboard focus: 0 mic, 1 desktop, -1 none; only a fader that is switched on takes it.
     */
    property int faderFocus: -1

    property Item focusRowItem: null
    function reportRowHover(item, hovered) {
        if (hovered)
            focusRowItem = item;
        else if (focusRowItem === item)
            focusRowItem = null;
    }
    function activateRow(row) {
        if (row === cursorRow)
            Flags.recordCursor = !Flags.recordCursor;
    }

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

    Process {
        id: rmClipProc
        onExited: ScreenRec.refreshRecent()
    }

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

    function handleKey(e) {
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Right)
            return stepFocused(5);
        if (e.key === Qt.Key_Down || e.key === Qt.Key_Left)
            return stepFocused(-5);
        return false;
    }

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

    /**
     * This surface's share of ScreenRec.recorderOpenCount, synced however the surface came to be open.
     */
    property bool counted: false
    function syncCount() {
        if (active !== counted) {
            ScreenRec.recorderOpenCount += active ? 1 : -1;
            counted = active;
        }
    }
    Component.onCompleted: syncCount()
    Component.onDestruction: if (counted) ScreenRec.recorderOpenCount--
    onActiveChanged: {
        syncCount();
        if (active) {
            ScreenRec.refreshRecent();
            faderFocus = -1;
            drawerOpen = false;
        }
        chooserOpen = false;
        screenChooserOpen = false;
        focusRowItem = null;
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: ScreenRec.recording
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.floor((Date.now() - ScreenRec.startedAt) / 1000)
    }

    Connections {
        target: ScreenRec
        function onRecordingChanged() {
            if (ScreenRec.recording) {
                root.drawerOpen = false;
                root.chooserOpen = false;
                root.screenChooserOpen = false;
            }
        }
    }

    /**
     * Glyph, a name that switches the source on and off, and a flat-tick fader that dims while the source is off.
     */
    component AudioRow: Item {
        id: arow
        property string glyph: ""
        property string name: ""
        property bool on: false
        property int faderIndex: -1
        property real level: 0.5
        signal faderMoved(real v)
        signal toggled()

        width: parent ? parent.width : 0
        height: 28 * root.s

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
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 84 * root.s
            text: arow.name
            color: arow.on || toggleArea.containsMouse ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.body * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: toggleArea
            anchors.left: parent.left
            anchors.right: rowName.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arow.toggled()
        }

        HFader {
            id: fader
            anchors.left: rowName.right
            anchors.leftMargin: Theme.sp.xs * root.s
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

        SurfaceHeader {
            s: root.s
            glyph: "録"
            title: "Recorder"

            Row {
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp.xs * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ScreenRec.recording
                    width: 7 * root.s
                    height: 7 * root.s
                    radius: width / 2
                    color: Theme.verm
                    SequentialAnimation on opacity {
                        running: ScreenRec.recording && root.visible && !Motion.calm
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: Motion.pulse; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenRec.recording ? root.fmtTime(root.elapsed) : (root.counting ? "Get ready" : "Idle")
                    color: ScreenRec.recording ? Theme.vermLit : Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Item {
            id: stageGroup
            width: parent.width
            height: stage.height + drawer.height

            Rectangle {
                id: stage
                readonly property bool canToggle: !ScreenRec.recording && !root.counting && !root.chooserOpen
                width: parent.width
                height: 76 * root.s
                radius: Theme.r.l * root.s
                color: Theme.cardBot

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius + 1
                    visible: root.drawerOpen
                    color: Theme.cardBot
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    bottomLeftRadius: root.drawerOpen ? 0 : radius
                    bottomRightRadius: root.drawerOpen ? 0 : radius
                    color: stageArea.pressed && stage.canToggle ? Theme.pressBg
                        : (stageArea.containsMouse && stage.canToggle ? Theme.frameBg : "transparent")
                    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
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
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

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
                    anchors.rightMargin: Theme.sp.m * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp.xs * root.s

                    Text {
                        width: parent.width
                        text: root.stageTitle
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.body * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Row {
                        width: parent.width
                        spacing: Theme.sp.xs * root.s

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
                            font.pixelSize: Theme.fs.meta * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    visible: ScreenRec.recording
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.l * root.s
                    anchors.top: parent.top
                    anchors.topMargin: Theme.sp.m * root.s
                    spacing: Theme.sp.xs * root.s

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6 * root.s
                        height: 6 * root.s
                        radius: width / 2
                        color: Theme.verm
                    }
                    Text {
                        text: "Rec"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.DemiBold
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
                    id: stageArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: stage.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (stage.canToggle) root.drawerOpen = !root.drawerOpen
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
                    radius: Theme.r.l * root.s
                    color: Theme.cardBot
                }
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Theme.r.l * root.s + 1
                    color: Theme.cardBot
                }

                Column {
                    id: drawerCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.sp.xs * root.s
                    anchors.rightMargin: Theme.sp.xs * root.s
                    bottomPadding: Theme.sp.xs * root.s

                    SettingsRow {
                        surface: root
                        icon: "video"
                        name: "Frame rate"
                        SettingsSeg {
                            s: root.s
                            options: [
                                { label: "30", value: 30 },
                                { label: "60", value: 60 },
                                { label: "120", value: 120 },
                                { label: "144", value: 144 }
                            ]
                            value: ScreenRec.fps
                            onPicked: (v) => Flags.recordFps = v
                        }
                    }
                    SettingsRow {
                        surface: root
                        icon: "sparkles"
                        name: "Quality"
                        SettingsSeg {
                            s: root.s
                            options: [
                                { label: "Med", value: "medium" },
                                { label: "High", value: "high" },
                                { label: "Ultra", value: "ultra" },
                                { label: "Lossless", value: "lossless" }
                            ]
                            value: ScreenRec.quality
                            onPicked: (v) => Flags.recordQuality = v
                        }
                    }
                    SettingsRow {
                        id: cursorRow
                        surface: root
                        icon: "cursor"
                        name: "Capture cursor"
                        LinkToggle {
                            s: root.s
                            on: ScreenRec.captureCursor
                            onToggled: Flags.recordCursor = !Flags.recordCursor
                        }
                    }
                    SettingsRow {
                        surface: root
                        icon: "stopwatch"
                        name: "Countdown"
                        last: true
                        SettingsSeg {
                            s: root.s
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

        Item { width: 1; height: Theme.sp.m * root.s }

        Item {
            id: actionGroup
            width: parent.width
            height: 44 * root.s

            Rectangle {
                id: actionBar
                anchors.fill: parent
                radius: Theme.r.l * root.s
                clip: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ScreenRec.recording ? Qt.alpha(Theme.verm, 0.34) : Qt.alpha(Theme.verm, 0.2) }
                    GradientStop { position: 1.0; color: ScreenRec.recording ? Qt.alpha(Theme.verm, 0.16) : Qt.alpha(Theme.flameGlow, 0.09) }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: actionBar.radius
                    color: actionArea.pressed ? Theme.pressBg : (actionArea.containsMouse ? Theme.frameBg : "transparent")
                    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    /**
                     * Linear on purpose: the fill is the countdown's clock.
                     */
                    Rectangle {
                        id: cdFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        visible: root.counting
                        width: parent.width * progress
                        color: Qt.alpha(Theme.vermLit, 0.18)

                        property real progress: 0
                        NumberAnimation on progress {
                            running: root.counting
                            from: 0
                            to: 1
                            duration: Math.max(1, Flags.recordCountdown) * 1000
                        }
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
                    radius: Theme.r.xs * root.s
                    color: Theme.vermLit
                    SequentialAnimation on scale {
                        running: ScreenRec.recording && root.visible && !Motion.calm
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.08; duration: Motion.pulse; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                    }
                }

                Text {
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
                    anchors.leftMargin: 46 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenRec.recording ? "Stop recording" : (root.counting ? "Starting…" : "Start recording")
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 18 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.counting ? "Click to cancel" : "Click"
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: actionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.press()
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.chooserOpen || root.screenChooserOpen
                radius: Theme.r.l * root.s
                color: Theme.cardBot
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.screenChooserOpen) {
                            root.screenChooserOpen = false;
                        } else {
                            root.chooserOpen = false;
                        }
                    }
                }

                SourceChooser {
                    anchors.fill: parent
                    anchors.margins: Theme.sp.xs * root.s
                    s: root.s
                    screenName: root.screenName
                    screens: root.screenChooserOpen
                    onWantScreens: root.screenChooserOpen = true
                    onResolved: {
                        root.chooserOpen = false;
                        root.screenChooserOpen = false;
                    }
                    onBack: {
                        root.screenChooserOpen = false;
                        root.chooserOpen = true;
                    }
                }
            }
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        AudioRow {
            glyph: "mic"
            name: "Microphone"
            on: ScreenRec.micOn
            faderIndex: 0
            level: root.source && root.source.audio ? root.source.audio.volume : 0
            onFaderMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }
            onToggled: Flags.recordMic = !Flags.recordMic
        }

        AudioRow {
            glyph: "speaker"
            name: "Desktop"
            on: ScreenRec.desktopOn
            faderIndex: 1
            level: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            onFaderMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
            onToggled: Flags.recordDesktop = !Flags.recordDesktop
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Item {
            id: pathRow
            width: parent.width
            height: 28 * root.s

            readonly property string shownDir: {
                var d = ScreenRec.outDir;
                var h = ScreenRec.home;
                return h.length > 0 && d.indexOf(h) === 0 ? "~" + d.slice(h.length) : d;
            }

            Text {
                id: pathLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Save to"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
            }

            /**
             * Ghost buttons sit their label, not their hover fill, on the content edge.
             */
            Row {
                id: pathActions
                anchors.right: parent.right
                anchors.rightMargin: -Theme.sp.m * root.s
                anchors.verticalCenter: parent.verticalCenter

                Button {
                    s: root.s
                    kind: "ghost"
                    text: "Change"
                    onClicked: ScreenRec.pickDir()
                }
                Button {
                    s: root.s
                    kind: "ghost"
                    text: "Open"
                    onClicked: ScreenRec.openDir()
                }
            }

            Text {
                anchors.left: pathLabel.right
                anchors.leftMargin: Theme.sp.s * root.s
                anchors.right: pathActions.left
                anchors.rightMargin: Theme.sp.xs * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: pathRow.shownDir
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: Theme.sp.s * root.s }

        Item {
            width: parent.width
            height: 28 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp.xs * root.s

                Text {
                    visible: Flags.showGlyphs
                    anchors.verticalCenter: parent.verticalCenter
                    text: "録"
                    color: Theme.subtle
                    font.family: Theme.fontJp
                    font.pixelSize: 11 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Recent · " + ScreenRec.recentCount
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.DemiBold
                }
            }

            Button {
                anchors.right: parent.right
                anchors.rightMargin: -Theme.sp.m * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: ScreenRec.recentCount > 0
                s: root.s
                kind: "ghost"
                text: "Clear"
                onClicked: ScreenRec.clearRecent()
            }
        }

        Item { width: 1; height: Theme.sp.xs * root.s }

        Item {
            width: parent.width
            height: 64 * root.s

            EmptyState {
                anchors.centerIn: parent
                visible: ScreenRec.recentCount === 0
                s: root.s
                text: "No recordings yet"
            }

            ListView {
                id: filmstrip
                anchors.fill: parent
                visible: ScreenRec.recentCount > 0
                orientation: ListView.Horizontal
                clip: true
                spacing: Theme.sp.s * root.s
                boundsBehavior: Flickable.StopAtBounds
                model: ScreenRec.recent

                delegate: Item {
                    id: frame
                    required property int index
                    required property var modelData

                    /**
                     * `recording_YYYY-MM-DD_HH-MM-SS` shown as `MM-DD HH:MM`, leaving room for the size.
                     */
                    readonly property string stamp: {
                        var m = /_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})/.exec(frame.modelData.name);
                        return m ? m[2] + "-" + m[3] + " " + m[4] + ":" + m[5]
                                 : frame.modelData.name.replace("recording_", "").replace(".mp4", "");
                    }
                    readonly property bool coverReady: cover.status === Image.Ready && cover.source !== ""

                    /**
                     * Two-step delete: the first click arms it red, the second removes the clip.
                     */
                    property bool armed: false

                    width: 110 * root.s
                    height: filmstrip.height
                    scale: frameArea.pressed && !delClipArea.containsMouse && !Motion.calm ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    ClippingRectangle {
                        id: thumb
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 48 * root.s
                        radius: Theme.r.m * root.s
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
                            cache: false
                            smooth: true
                            sourceSize.width: 220 * root.s
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
                            color: Qt.alpha(Theme.cardBot, 0.55)
                            opacity: frameArea.containsMouse ? 1 : 0.7
                            Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

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
                        anchors.top: thumb.bottom
                        anchors.topMargin: Theme.sp.xs * root.s
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: stampTxt.height

                        Text {
                            id: stampTxt
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: sizeTxt.left
                            anchors.rightMargin: Theme.sp.xs * root.s
                            text: frame.stamp
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
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
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.label * root.s
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

                    Rectangle {
                        id: delBadge
                        anchors.top: thumb.top
                        anchors.right: thumb.right
                        anchors.margins: Theme.sp.xs * root.s
                        width: 15 * root.s
                        height: 15 * root.s
                        radius: width / 2
                        color: frame.armed ? Theme.danger : Qt.alpha(Theme.cardBot, 0.7)
                        opacity: frameArea.containsMouse || delClipArea.containsMouse ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 8 * root.s
                            height: 8 * root.s
                            name: "close"
                            stroke: 2
                            color: frame.armed || delClipArea.containsMouse ? Theme.cream : Theme.subtle
                        }

                        MouseArea {
                            id: delClipArea
                            anchors.fill: parent
                            anchors.margins: -Theme.sp.xs * root.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onExited: frame.armed = false
                            onClicked: {
                                if (!frame.armed) {
                                    frame.armed = true;
                                    return;
                                }
                                frame.armed = false;
                                rmClipProc.command = ["rm", "--", frame.modelData.path];
                                rmClipProc.running = true;
                            }
                        }
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
