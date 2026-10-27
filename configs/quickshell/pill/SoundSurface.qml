pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import "Singletons"

/** 音 SOUND surface with three tabs: EQ (boost, spectrum, modes, ten bands, shelves, AutoEQ, night), Apps (per-app volume, mute, output) and Mic (input, gain, noise filter). */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight
    holdsFocus: aeqOpen || renaming.length > 0

    property string tab: "eq"
    property bool editing: false
    property var routeStream: null
    property bool aeqOpen: false
    /** Top edge of the AutoEQ row in surface coordinates; layout deps are voided so the picker follows tab and size changes. */
    readonly property real aeqTop: {
        void eqBody.y;
        void eqBody.height;
        void aeqRow.y;
        return aeqRow.mapToItem(root, 0, 0).y;
    }
    property string aeqQuery: ""
    property real routeY: 0
    property bool pickerOpen: false
    property bool boostOpen: false
    property string renaming: ""
    property int focusBand: -1
    property int kbApp: -1
    readonly property var levels: counted ? Cava.spectrum : []

    readonly property var labels: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var tabs: ["eq", "apps", "mic"]

    readonly property bool micTab: tab === "mic"

    ameForm: focusBand >= 0 ? "tick" : "off"
    amePoint: {
        void root.focusBand;
        const b = bandRep.itemAt(root.focusBand);
        return b ? b.tickCenter : Qt.point(width / 2, height / 2);
    }

    onActiveChanged: {
        if (active)
            return;
        closeMenus();
        editing = false;
        renaming = "";
        focusBand = -1;
        kbApp = -1;
    }

    function closeMenus() {
        pickerOpen = false;
        boostOpen = false;
        routeStream = null;
        aeqOpen = false;
    }

    function pickTab(v) {
        tab = v;
        editing = false;
        kbApp = -1;
        closeMenus();
    }

    function back() {
        if (renaming.length) {
            renaming = "";
            return true;
        }
        if (pickerOpen || boostOpen || aeqOpen || routeStream !== null) {
            closeMenus();
            return true;
        }
        if (editing) {
            editing = false;
            return true;
        }
        return false;
    }

    /** Tab cycles the tabs; arrows pick a band or app and nudge its value; Enter mutes an app or flips the mic filter. */
    function handleKey(e) {
        const enter = e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space;
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            const i = tabs.indexOf(tab);
            pickTab(tabs[(i + (e.key === Qt.Key_Tab ? 1 : tabs.length - 1)) % tabs.length]);
            return true;
        }
        if (tab === "eq") {
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
                const dir = e.key === Qt.Key_Left ? -1 : 1;
                focusBand = focusBand < 0 ? (dir > 0 ? 0 : 9) : Math.max(0, Math.min(9, focusBand + dir));
                return true;
            }
            if ((e.key === Qt.Key_Up || e.key === Qt.Key_Down) && focusBand >= 0) {
                const db = Sound.current.bands[focusBand] || 0;
                Sound.setBand(focusBand, Math.max(-Sound.range, Math.min(Sound.range, db + (e.key === Qt.Key_Up ? 0.5 : -0.5))));
                return true;
            }
            return false;
        }
        if (tab === "apps") {
            const n = Sound.apps.length;
            if (!n)
                return false;
            if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
                kbApp = kbApp < 0 ? 0 : Math.max(0, Math.min(n - 1, kbApp + (e.key === Qt.Key_Up ? -1 : 1)));
                appsList.positionViewAtIndex(kbApp, ListView.Contain);
                return true;
            }
            const node = Sound.apps[kbApp];
            if (!node || !node.audio)
                return false;
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
                const v = Math.max(0, Math.min(2, node.audio.volume + (e.key === Qt.Key_Right ? 0.05 : -0.05)));
                Sound.setNodeVolume(node, Math.round(v * 100) / 100, "app" + node.id, "App volume");
                return true;
            }
            if (enter && !e.isAutoRepeat) {
                Sound.setNodeMuted(node, !node.audio.muted);
                return true;
            }
            return false;
        }
        const src = Sound.source;
        if ((e.key === Qt.Key_Left || e.key === Qt.Key_Right) && src && src.audio) {
            const v = Math.max(0, Math.min(2, src.audio.volume + (e.key === Qt.Key_Right ? 0.05 : -0.05)));
            Sound.setNodeVolume(src, Math.round(v * 100) / 100, "micvol", "Mic volume");
            return true;
        }
        if (enter && !e.isAutoRepeat && Sound.denoiseAvailable) {
            Sound.setDenoise(!Sound.denoise);
            return true;
        }
        return false;
    }

    /** App label from the stream: the binary when the client only reports a generic engine name (Chromium, WebRTC). */
    function appName(node, p) {
        const bin = p["application.process.binary"] || "";
        const name = p["application.name"] || "";
        if (bin && !/wine|preloader|python|java|\.exe$/i.test(bin) && (!name || /chrom|webrtc|electron|playback|alsa/i.test(name)))
            return bin.charAt(0).toUpperCase() + bin.slice(1);
        return name || node.description || node.name || "App";
    }

    function fmtDb(v) {
        return (v > 0 ? "+" : "") + (Math.round(v * 10) / 10);
    }

    PwObjectTracker {
        objects: Sound.outputs.concat(Sound.inputs)
    }

    /** This surface's share of Cava.consumers while the EQ spectrum is on screen. */
    readonly property bool eqShown: root.open && root.tab === "eq"
    property bool counted: false
    function syncCount() {
        if (eqShown !== counted) {
            Cava.consumers += eqShown ? 1 : -1;
            counted = eqShown;
        }
    }
    onEqShownChanged: syncCount()
    Component.onCompleted: syncCount()
    Component.onDestruction: if (counted) Cava.consumers--

    FontMetrics {
        id: metaFm
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
    }

    component Caption: Text {
        color: Theme.textFaint
        font.family: Theme.font
        font.pixelSize: Theme.fs.meta * root.s
        font.weight: Font.DemiBold
    }

    component IconButton: Item {
        id: ib
        property string glyph: ""
        property string tip: ""
        signal clicked()

        width: 15 * root.s
        height: 15 * root.s

        GlyphIcon {
            anchors.fill: parent
            name: ib.glyph
            color: ibArea.pressed ? Theme.vermLit : (ibArea.containsMouse ? Theme.cream : Theme.iconDim)
            stroke: 1.8
        }

        MouseArea {
            id: ibArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: ib.tip
            show: ibArea.containsMouse
        }
    }

    component ModeChip: Rectangle {
        id: chip
        required property var modelData
        readonly property string name: modelData.name
        readonly property bool current: Sound.current.mode === name
        readonly property bool editingName: root.renaming === name

        width: (chip.editingName ? Math.max(nameInput.contentWidth, 36 * root.s) : chipLabel.implicitWidth) + 2 * Theme.sp.s * root.s
        height: 28 * root.s
        radius: Theme.r.s * root.s
        color: chip.current ? Qt.alpha(Theme.onGlow, chipArea.pressed ? 0.22 : 0.16)
            : (chipArea.pressed ? Theme.pressBg : (chipHover.hovered ? Theme.frameBg : "transparent"))
        border.width: 1
        border.color: chip.current ? Qt.alpha(Theme.onGlow, 0.4) : Theme.border
        scale: chipArea.pressed && !Motion.calm ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        HoverHandler { id: chipHover }

        Text {
            id: chipLabel
            visible: !chip.editingName
            anchors.centerIn: parent
            text: chip.name + (chip.current && Sound.dirty ? " •" : "")
            color: chip.current ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.Bold
        }

        TextInput {
            id: nameInput
            visible: chip.editingName
            anchors.centerIn: parent
            text: chip.name
            color: Theme.cream
            selectionColor: Theme.verm
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.Bold
            maximumLength: 18
            onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
            onAccepted: { Sound.rename(chip.name, text); root.renaming = ""; }
            onActiveFocusChanged: if (!activeFocus && chip.editingName) root.renaming = ""
            Keys.onEscapePressed: root.renaming = ""
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            enabled: !chip.editingName
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!root.editing) Sound.pick(chip.name)
            onDoubleClicked: root.renaming = chip.name
        }

        Rectangle {
            visible: root.editing
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -Theme.sp.xs * root.s
            anchors.topMargin: -Theme.sp.xs * root.s
            width: 13 * root.s
            height: 13 * root.s
            radius: width / 2
            color: minusArea.containsMouse ? Theme.vermLit : Theme.verm

            Rectangle {
                anchors.centerIn: parent
                width: 6 * root.s
                height: 1.6 * root.s
                radius: height / 2
                color: Theme.bright
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.remove(chip.name)
            }
        }
    }

    component EqBand: Item {
        id: band
        required property int index
        readonly property real db: Sound.current.bands[index] || 0
        readonly property bool lit: root.focusBand === index || bandDrag.pressed
        readonly property real trackH: 70 * root.s
        readonly property real tickY: (1 - (db + Sound.range) / (2 * Sound.range)) * trackH

        /** Tick centre in surface coordinates; y and width are voided so the mapping re-runs as the value or layout moves. */
        readonly property point tickCenter: {
            void band.tickY;
            void band.width;
            return track.mapToItem(root, track.width / 2, band.tickY);
        }

        width: bandsRow.width / 10
        height: 2 * metaFm.height + 9 * root.s + trackH

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    root.focusBand = band.index;
                else if (root.focusBand === band.index)
                    root.focusBand = -1;
            }
        }

        Text {
            id: dbLabel
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.fmtDb(band.db)
            color: band.lit ? Theme.cream : (band.db !== 0 ? Theme.subtle : Theme.textFaint)
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Item {
            id: track
            y: metaFm.height + 4 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22 * root.s
            height: band.trackH

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * root.s
                height: parent.height
                radius: width / 2
                color: Theme.threadBg
            }

            Rectangle {
                anchors.centerIn: parent
                width: 9 * root.s
                height: 1
                color: Theme.hair
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * root.s
                radius: width / 2
                y: Math.min(band.tickY, band.trackH / 2)
                height: Math.abs(band.tickY - band.trackH / 2)
                color: band.lit ? Theme.vermLit : Theme.vermDim
                Behavior on y { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                Behavior on height { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: band.tickY - height / 2
                width: 11 * root.s
                height: 2.5 * root.s
                radius: 2 * root.s
                color: Theme.tickRest
                opacity: band.lit ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            MouseArea {
                id: bandDrag
                anchors.fill: parent
                anchors.margins: -8 * root.s
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function setFromY(my) {
                    const t = Math.max(0, Math.min(1, (my - 8 * root.s) / band.trackH));
                    Sound.setBand(band.index, Math.round((1 - 2 * t) * Sound.range * 2) / 2);
                }
                onPressed: (e) => setFromY(e.y)
                onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
                onDoubleClicked: Sound.setBand(band.index, 0)
                onWheel: (w) => Sound.setBand(band.index, Math.max(-Sound.range, Math.min(Sound.range, band.db + (w.angleDelta.y > 0 ? 0.5 : -0.5))))
            }
        }

        Text {
            anchors.top: track.bottom
            anchors.topMargin: 5 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.labels[band.index]
            color: band.lit ? Theme.cream : Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
        }
    }

    component AppRow: Item {
        id: app
        required property var modelData
        required property int index
        readonly property var props: modelData.properties || {}
        readonly property var target: Sound.targetOf(modelData)
        readonly property real vol: modelData.audio ? modelData.audio.volume : 0
        readonly property bool muted: modelData.audio ? modelData.audio.muted : false
        readonly property bool lit: appHover.hovered || root.kbApp === index

        width: appsList.width
        height: 42 * root.s

        HoverHandler {
            id: appHover
            onHoveredChanged: if (hovered) root.kbApp = app.index
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Theme.sp.xxs * root.s
            anchors.bottomMargin: Theme.sp.xxs * root.s
            radius: Theme.r.m * root.s
            color: app.lit ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Column {
            id: appText
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 108 * root.s
            spacing: Theme.sp.xxs * root.s
            Text {
                width: parent.width
                text: root.appName(app.modelData, app.props)
                elide: Text.ElideRight
                color: app.lit ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: app.props["media.name"] || ""
                elide: Text.ElideRight
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
            }
        }

        Item {
            id: muteBtn
            anchors.left: appText.right
            anchors.leftMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s

            GlyphIcon {
                anchors.fill: parent
                name: app.muted ? "speaker-off" : "speaker"
                color: muteArea.pressed ? Theme.vermLit : (app.muted ? Theme.textFaint : (muteArea.containsMouse ? Theme.cream : Theme.iconDim))
                stroke: 1.7
            }

            MouseArea {
                id: muteArea
                anchors.fill: parent
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.setNodeMuted(app.modelData, !app.muted)
            }
        }

        HFader {
            anchors.left: muteBtn.right
            anchors.leftMargin: Theme.sp.m * root.s
            anchors.right: devChip.left
            anchors.rightMargin: Theme.sp.m * root.s
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            value: app.vol / 2
            readout: Math.round(app.vol * 100) + "%"
            focused: app.lit
            on: !app.muted
            onMoved: (v) => Sound.setNodeVolume(app.modelData, Math.round(v * 200) / 100, "app" + app.modelData.id, "App volume")
        }

        Rectangle {
            id: devChip
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 90 * root.s
            height: 24 * root.s
            radius: Theme.r.s * root.s
            color: root.routeStream === app.modelData ? Qt.alpha(Theme.onGlow, 0.14)
                : (chipArea.pressed ? Theme.pressBg : (chipArea.containsMouse ? Theme.frameBg : "transparent"))
            border.width: 1
            border.color: root.routeStream === app.modelData ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

            Text {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp.s * root.s
                anchors.rightMargin: Theme.sp.s * root.s
                verticalAlignment: Text.AlignVCenter
                text: app.target ? (app.target.nickname || Sound.label(app.target)) : "Default"
                elide: Text.ElideRight
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.routeY = app.mapToItem(root, 0, app.height).y;
                    root.routeStream = root.routeStream === app.modelData ? null : app.modelData;
                }
            }
        }
    }

    component MiniShelf: Item {
        id: shelf
        property string label: ""
        property real value: 0
        property bool bipolar: true
        property string readout: ""
        signal moved(real v)

        readonly property bool lit: shelfHover.hovered || shelfDrag.pressed
        readonly property real clamped: Math.max(0, Math.min(1, value))

        height: 30 * root.s

        HoverHandler { id: shelfHover }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: shelf.label
            color: shelf.lit ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: shelf.readout
            color: shelf.lit ? Theme.cream : Theme.textFaint
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            id: shelfTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sp.xs * root.s
            height: 3 * root.s
            radius: height / 2
            color: Theme.threadBg

            Rectangle {
                readonly property real from: shelf.bipolar ? 0.5 : 0
                x: shelfTrack.width * Math.min(from, shelf.clamped)
                width: shelfTrack.width * Math.abs(shelf.clamped - from)
                height: parent.height
                radius: parent.radius
                color: shelf.lit ? Theme.vermLit : Theme.vermDim
            }

            Rectangle {
                x: Math.max(0, Math.min(shelfTrack.width - width, shelfTrack.width * shelf.clamped - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 2.5 * root.s
                height: 10 * root.s
                radius: 2 * root.s
                color: Theme.tickRest
            }

            MouseArea {
                id: shelfDrag
                anchors.fill: parent
                anchors.margins: -8 * root.s
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function setFromX(mx) {
                    shelf.moved(Math.max(0, Math.min(1, (mx - 8 * root.s) / shelfTrack.width)));
                }
                onPressed: (e) => setFromX(e.x)
                onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
                onDoubleClicked: shelf.moved(shelf.bipolar ? 0.5 : 0)
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            height: 24 * root.s
            s: root.s
            glyph: "音"
            title: "Sound"
            titleContent: SettingsSeg {
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                options: [{ label: "EQ", value: "eq" }, { label: "Apps", value: "apps" }, { label: "Mic", value: "mic" }]
                value: root.tab
                onPicked: (v) => root.pickTab(v)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp.m * root.s

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Sound.undoStack.length > 0
                    glyph: "undo"
                    tip: "Undo " + Sound.undoLabel.toLowerCase()
                    onClicked: Sound.undo()
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Players.has
                    glyph: "music"
                    tip: "Open media"
                    onClicked: root.requestSurface("media")
                }

                LinkToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.tab === "eq"
                    s: root.s
                    on: Sound.eq
                    onToggled: Sound.setEq(!Sound.eq)

                    HoverHandler { id: eqHover }

                    Tooltip {
                        s: root.s
                        placement: "below"
                        title: Sound.eq ? "Equalizer on" : "Equalizer off"
                        desc: "Applies the bands below to this output"
                        show: eqHover.hovered
                    }
                }
            }
        }

        Item { width: 1; height: Theme.sp.s * root.s }
        Rectangle { width: parent.width; height: 1; color: Theme.hair }
        Item { width: 1; height: Theme.sp.m * root.s }

        Item {
            id: deviceRow
            width: parent.width
            height: 28 * root.s

            Caption {
                id: outLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 56 * root.s
                text: root.micTab ? "Input" : "Output"
            }

            Rectangle {
                id: boostChip
                visible: !root.micTab
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 58 * root.s
                height: 28 * root.s
                radius: Theme.r.s * root.s
                readonly property int pct: Sound.current.boost || 100
                color: root.boostOpen ? Qt.alpha(Theme.onGlow, 0.14)
                    : (boostArea.pressed ? Theme.pressBg : (boostArea.containsMouse ? Theme.frameBg : "transparent"))
                border.width: 1
                border.color: root.boostOpen ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: boostChip.pct + "%"
                    color: boostChip.pct > 100 ? Theme.vermLit : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }

                MouseArea {
                    id: boostArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.boostOpen = !root.boostOpen; root.pickerOpen = false; }
                }

                Tooltip {
                    s: root.s
                    placement: "below"
                    title: "Volume boost"
                    desc: "Lets this output go past 100%, which can distort"
                    show: boostArea.containsMouse && !root.boostOpen
                }
            }

            Rectangle {
                id: deviceField
                anchors.left: outLabel.right
                anchors.leftMargin: Theme.sp.s * root.s
                anchors.right: root.micTab ? parent.right : boostChip.left
                anchors.rightMargin: root.micTab ? 0 : Theme.sp.s * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 28 * root.s
                radius: Theme.r.s * root.s
                color: root.pickerOpen ? Qt.alpha(Theme.onGlow, 0.14)
                    : (fieldArea.pressed ? Theme.pressBg : (fieldHover.hovered ? Theme.frameBg : "transparent"))
                border.width: 1
                border.color: root.pickerOpen ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                HoverHandler { id: fieldHover }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp.s * root.s
                    anchors.right: chevron.left
                    anchors.rightMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sound.label(root.micTab ? Sound.source : Sound.sink) || (root.micTab ? "No input" : "No output")
                    elide: Text.ElideRight
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.weight: Font.DemiBold
                }

                GlyphIcon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp.s * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s
                    height: 12 * root.s
                    name: root.pickerOpen ? "chevron-up" : "chevron-down"
                    color: Theme.iconDim
                    stroke: 2
                }

                MouseArea {
                    id: fieldArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.pickerOpen = !root.pickerOpen; root.boostOpen = false; }
                }
            }
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Column {
            visible: root.micTab
            width: parent.width
            spacing: Theme.sp.m * root.s

            Item {
                width: parent.width
                height: 28 * root.s

                Caption {
                    id: gainLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: outLabel.width
                    text: "Volume"
                }

                HFader {
                    anchors.left: gainLabel.right
                    anchors.leftMargin: Theme.sp.s * root.s
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    readonly property real vol: Sound.source && Sound.source.audio ? Sound.source.audio.volume : 0
                    value: vol / 2
                    readout: Math.round(vol * 100) + "%"
                    focused: gainHover.hovered
                    onMoved: (v) => Sound.setNodeVolume(Sound.source, Math.round(v * 200) / 100, "micvol", "Mic volume")
                    HoverHandler { id: gainHover }
                }
            }

            Item {
                width: parent.width
                height: 36 * root.s

                Column {
                    anchors.left: parent.left
                    anchors.right: denoiseToggle.left
                    anchors.rightMargin: Theme.sp.m * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp.xxs * root.s
                    Text {
                        text: "Noise filter"
                        color: Sound.denoiseAvailable ? Theme.cream : Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: Sound.denoiseAvailable ? "Cleans background noise out of the mic for every app"
                            : "Needs the noise-suppression-for-voice package"
                        elide: Text.ElideRight
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                    }
                }

                LinkToggle {
                    id: denoiseToggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    enabled: Sound.denoiseAvailable
                    opacity: enabled ? 1 : 0.4
                    on: Sound.denoise && Sound.denoiseAvailable
                    onToggled: Sound.setDenoise(!Sound.denoise)
                }
            }
        }

        Item {
            id: eqBody
            visible: root.tab === "eq"
            width: parent.width
            height: eqCol.implicitHeight
            opacity: Sound.eq ? 1 : 0.5
            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }

            Column {
                id: eqCol
                width: parent.width
                spacing: 0

                Item {
                    width: parent.width
                    height: Math.max(modeFlow.height, modeActions.height)

                    Flow {
                        id: modeFlow
                        anchors.left: parent.left
                        anchors.right: modeActions.left
                        anchors.rightMargin: Theme.sp.s * root.s
                        spacing: Theme.sp.xs * root.s

                        Repeater {
                            model: Sound.modes
                            ModeChip {}
                        }

                        Rectangle {
                            visible: !root.editing
                            width: 28 * root.s
                            height: 28 * root.s
                            radius: Theme.r.s * root.s
                            color: addArea.pressed ? Theme.pressBg : (addHover.hovered ? Theme.frameBg : "transparent")
                            border.width: 1
                            border.color: Theme.border
                            Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                            HoverHandler { id: addHover }

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: addHover.hovered ? Theme.cream : Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: addArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Sound.add()
                            }

                            Tooltip {
                                s: root.s
                                placement: "below"
                                title: "New mode from this sound"
                                show: addHover.hovered
                            }
                        }
                    }

                    Row {
                        id: modeActions
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: Theme.sp.xs * root.s

                        Button {
                            visible: !root.editing && Sound.dirty && Sound.currentMode !== null
                            s: root.s
                            kind: "ghost"
                            text: "Save"
                            onClicked: Sound.save()
                        }
                        Button {
                            visible: root.editing
                            s: root.s
                            kind: "ghost"
                            text: "Reset"
                            onClicked: Sound.restoreDefaults()
                        }
                        Button {
                            s: root.s
                            kind: "ghost"
                            text: root.editing ? "Done" : "Edit"
                            lit: root.editing
                            onClicked: { root.editing = !root.editing; root.renaming = ""; }
                        }
                    }
                }

                Item { width: 1; height: Theme.sp.s * root.s }

                Item {
                    width: parent.width
                    height: bandsRow.height

                    /** Live spectrum drawn behind the band tracks, faint so the faders stay readable on top. */
                    Row {
                        id: barsRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.sp.xs * root.s
                        anchors.rightMargin: Theme.sp.xs * root.s
                        y: metaFm.height + 4 * root.s
                        height: 70 * root.s
                        spacing: 2 * root.s
                        opacity: 0.32

                        Repeater {
                            model: 40

                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: (barsRow.width - 39 * barsRow.spacing) / 40
                                radius: width / 2
                                height: Math.max(1, (root.levels[index] || 0) * barsRow.height)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.flameGlow }
                                    GradientStop { position: 1.0; color: Theme.vermLit }
                                }
                                Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad } }
                            }
                        }
                    }

                    Row {
                        id: bandsRow
                        width: parent.width

                        Repeater {
                            id: bandRep
                            model: 10
                            EqBand {}
                        }
                    }
                }

                Item { width: 1; height: Theme.sp.s * root.s }

                Row {
                    width: parent.width
                    spacing: Theme.sp.m * root.s

                    MiniShelf {
                        width: (parent.width - 2 * parent.spacing) / 3
                        label: "Bass"
                        value: (Sound.current.bass + Sound.range) / (2 * Sound.range)
                        readout: root.fmtDb(Sound.current.bass) + " dB"
                        onMoved: (v) => Sound.setValue("bass", Math.round((v * 2 - 1) * Sound.range * 2) / 2)
                    }
                    MiniShelf {
                        width: (parent.width - 2 * parent.spacing) / 3
                        label: "Treble"
                        value: (Sound.current.treble + Sound.range) / (2 * Sound.range)
                        readout: root.fmtDb(Sound.current.treble) + " dB"
                        onMoved: (v) => Sound.setValue("treble", Math.round((v * 2 - 1) * Sound.range * 2) / 2)
                    }
                    MiniShelf {
                        width: (parent.width - 2 * parent.spacing) / 3
                        label: "Widen"
                        bipolar: false
                        value: Sound.current.widen / 100
                        readout: Math.round(Sound.current.widen) + "%"
                        onMoved: (v) => Sound.setValue("widen", Math.round(v * 100))
                    }
                }

                Item { width: 1; height: Theme.sp.m * root.s }

                Item {
                    id: aeqRow
                    width: parent.width
                    height: 28 * root.s

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: nightLabel.left
                        anchors.rightMargin: Theme.sp.m * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28 * root.s
                        radius: Theme.r.s * root.s
                        color: root.aeqOpen ? Qt.alpha(Theme.onGlow, 0.14)
                            : (aeqArea.pressed ? Theme.pressBg : (aeqHover.hovered ? Theme.frameBg : "transparent"))
                        border.width: 1
                        border.color: root.aeqOpen ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        HoverHandler { id: aeqHover }

                        Text {
                            id: aeqTag
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.sp.s * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: "AutoEQ"
                            color: Sound.current.autoeq ? Theme.vermLit : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.left: aeqTag.right
                            anchors.leftMargin: Theme.sp.s * root.s
                            anchors.right: aeqClear.left
                            anchors.rightMargin: Theme.sp.s * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Sound.current.autoeq ? Sound.current.autoeq.name : "Pick headphones"
                            elide: Text.ElideRight
                            color: Sound.current.autoeq ? Theme.cream : Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Sound.current.autoeq ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: aeqArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.aeqOpen = !root.aeqOpen;
                                if (root.aeqOpen)
                                    Sound.loadAeqIndex();
                            }
                        }

                        GlyphIcon {
                            id: aeqClear
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp.s * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11 * root.s
                            height: 11 * root.s
                            name: Sound.current.autoeq ? "close" : "chevron-up"
                            color: clearArea.containsMouse ? Theme.cream : Theme.iconDim
                            stroke: 2

                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                anchors.margins: -6 * root.s
                                hoverEnabled: true
                                enabled: Sound.current.autoeq !== undefined && Sound.current.autoeq !== null
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Sound.clearAeq()
                            }
                        }
                    }

                    Text {
                        id: nightLabel
                        anchors.right: nightToggle.left
                        anchors.rightMargin: Theme.sp.s * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Night"
                        color: nightHover.hovered ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.DemiBold

                        HoverHandler { id: nightHover }

                        Tooltip {
                            s: root.s
                            placement: "above"
                            title: "Night mode"
                            desc: "Evens out loud and quiet parts"
                            show: nightHover.hovered
                        }
                    }

                    LinkToggle {
                        id: nightToggle
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        on: Sound.current.night === true
                        onToggled: Sound.setNight(Sound.current.night !== true)
                    }
                }
            }
        }

        Item {
            visible: root.tab === "apps"
            width: parent.width
            height: Sound.apps.length ? appsList.height : appsEmpty.implicitHeight

            EmptyState {
                id: appsEmpty
                visible: !Sound.apps.length
                anchors.horizontalCenter: parent.horizontalCenter
                s: root.s
                glyph: "speaker"
                text: "Nothing is playing"
            }

            ListView {
                id: appsList
                width: parent.width
                height: Math.min(count, 6) * 42 * root.s
                interactive: count > 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Sound.apps
                delegate: AppRow {}
            }
        }
    }

    Item {
        id: aeqPanel
        z: 8
        visible: root.aeqOpen
        y: root.aeqTop - height - 6 * root.s
        anchors.right: parent.right
        width: parent.width
        height: aeqCard.height

        readonly property var results: Sound.searchAeq(root.aeqQuery)

        Rectangle {
            anchors.fill: aeqCard
            radius: aeqCard.radius
            color: Theme.cardBot
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Rectangle {
            id: aeqCard
            width: parent.width
            height: aeqCol.implicitHeight + Theme.sp.s * root.s
            radius: Theme.r.m * root.s
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            border.width: 1
            border.color: Theme.frameBorder

            Column {
                id: aeqCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.sp.xs * root.s

                Repeater {
                    model: aeqPanel.results

                    Rectangle {
                        id: aeqRes
                        required property var modelData
                        width: aeqCol.width
                        height: 24 * root.s
                        radius: Theme.r.s * root.s
                        color: aeqResArea.pressed ? Theme.pressBg : (aeqResHover.hovered ? Theme.frameBg : "transparent")
                        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                        HoverHandler { id: aeqResHover }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.sp.s * root.s
                            anchors.right: aeqBy.left
                            anchors.rightMargin: Theme.sp.s * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: aeqRes.modelData.name
                            elide: Text.ElideRight
                            color: aeqResHover.hovered ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                            font.weight: Font.Medium
                        }

                        Text {
                            id: aeqBy
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp.s * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: aeqRes.modelData.by
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.meta * root.s
                        }

                        MouseArea {
                            id: aeqResArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Sound.pickAeq(aeqRes.modelData);
                                root.aeqOpen = false;
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.hair; visible: aeqPanel.results.length > 0 }

                Item {
                    width: parent.width
                    height: 28 * root.s

                    TextInput {
                        id: aeqInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp.s * root.s
                        anchors.rightMargin: Theme.sp.s * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        selectionColor: Theme.verm
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        onTextChanged: root.aeqQuery = text
                        Keys.onEscapePressed: root.aeqOpen = false
                        Keys.onReturnPressed: if (aeqPanel.results.length) { Sound.pickAeq(aeqPanel.results[0]); root.aeqOpen = false; }
                        Connections {
                            target: root
                            function onAeqOpenChanged() {
                                if (root.aeqOpen)
                                    aeqInput.forceActiveFocus();
                            }
                        }

                        Text {
                            visible: !aeqInput.text.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: Sound.aeqLoading ? "Loading the headphone list…" : (Sound.aeqError || "Search headphones, e.g. HD 600")
                            color: Theme.textFaint
                            font: aeqInput.font
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: boostMenu
        z: 7
        visible: root.boostOpen
        anchors.top: parent.top
        anchors.topMargin: deviceRow.y + deviceRow.height + Theme.sp.xs * root.s
        anchors.right: parent.right
        width: 76 * root.s
        height: boostCol.implicitHeight + Theme.sp.xs * root.s
        radius: Theme.r.m * root.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.frameBorder

        Column {
            id: boostCol
            anchors.centerIn: parent
            width: parent.width - Theme.sp.xs * root.s

            Repeater {
                model: [100, 125, 150, 175, 200]

                Rectangle {
                    id: boostOpt
                    required property int modelData
                    width: boostCol.width
                    height: 24 * root.s
                    radius: Theme.r.s * root.s
                    color: boostOptArea.pressed ? Theme.pressBg
                        : boostOptHover.hovered ? Theme.frameBg
                        : ((Sound.current.boost || 100) === modelData ? Qt.alpha(Theme.onGlow, 0.16) : "transparent")
                    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    HoverHandler { id: boostOptHover }

                    Text {
                        anchors.centerIn: parent
                        text: boostOpt.modelData === 100 ? "Off" : boostOpt.modelData + "%"
                        color: (Sound.current.boost || 100) === boostOpt.modelData ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.meta * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: boostOptArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sound.setBoost(boostOpt.modelData);
                            root.boostOpen = false;
                        }
                    }
                }
            }
        }
    }

    DeviceMenu {
        s: root.s
        open: root.routeStream !== null
        anchors.top: parent.top
        anchors.topMargin: root.routeY + Theme.sp.xxs * root.s
        anchors.right: parent.right
        width: 240 * root.s
        model: Sound.outputs
        current: root.routeStream ? Sound.targetOf(root.routeStream) : null
        onPick: (node) => {
            Sound.route(root.routeStream, node);
            root.routeStream = null;
        }
    }

    DeviceMenu {
        s: root.s
        open: root.pickerOpen
        anchors.top: parent.top
        anchors.topMargin: deviceRow.y + deviceRow.height + Theme.sp.xs * root.s
        anchors.right: parent.right
        width: deviceField.width
        model: root.micTab ? Sound.inputs : Sound.outputs
        current: root.micTab ? Sound.source : Sound.sink
        onPick: (node) => {
            if (root.micTab)
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
            root.pickerOpen = false;
        }
    }
}
