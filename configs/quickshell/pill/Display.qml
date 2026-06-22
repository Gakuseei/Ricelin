pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/monitors.js" as Mon
import "Singletons"

/**
 * 画 DISPLAY sub-surface: changes each monitor's resolution, refresh rate and
 * scale live through Hyprland's `hl.monitor` eval, behind a GNOME/KDE-style
 * auto-revert safety net. Reads `hyprctl monitors -j` on open and renders one
 * card per output with three segmented pickers: the distinct WxH from the
 * monitor's availableModes, the Hz available for the chosen WxH, and a fixed
 * scale set. Apply hands the new spec to display-apply.sh, which snapshots the
 * old spec, evals the new one and arms a detached 12s watchdog that reverts if
 * the change is not confirmed — so a mode that blanks the screen heals itself
 * even if the pill dies. A confirmed Keep clears the watchdog and persists by
 * rewriting only that output's block in monitors.lua. Reached from the settings
 * index; morphs back on the back chevron (an empty click is swallowed while a
 * confirmation countdown is live so a stray tap cannot lose the Keep button).
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property string monitorsPath: Quickshell.env("HOME") + "/.config/hypr/modules/monitors.lua"
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/display-apply.sh"

    property var monitors: []
    property string pendingOut: ""
    property string openPicker: ""
    property int countdown: 0
    property string note: ""

    readonly property var scaleOptions: [
        { label: "1.0", value: 1 },
        { label: "1.25", value: 1.25 },
        { label: "1.5", value: 1.5 },
        { label: "2.0", value: 2 }
    ]

    onActiveChanged: {
        if (active) {
            cancelCountdown();
            readProc.running = true;
        } else {
            cancelCountdown();
            openPicker = "";
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Reduces a monitor's parsed modes to the list of distinct WxH, each carrying
     * the descending list of whole-number Hz offered for that resolution. The
     * native (current width/height) resolution sorts first, then the rest by
     * pixel count descending, so the default selection lands on the panel's real
     * mode.
     */
    function resolutionsFor(mon) {
        var byRes = {};
        for (var i = 0; i < mon.modes.length; i++) {
            var m = mon.modes[i];
            var key = m.w + "x" + m.h;
            if (!byRes[key])
                byRes[key] = { w: m.w, h: m.h, key: key, rates: [] };
            if (byRes[key].rates.indexOf(m.hz) === -1)
                byRes[key].rates.push(m.hz);
        }
        var list = [];
        for (var k in byRes) {
            byRes[k].rates.sort(function (a, b) { return b - a; });
            list.push(byRes[k]);
        }
        list.sort(function (a, b) {
            if (a.w === mon.width && a.h === mon.height) return -1;
            if (b.w === mon.width && b.h === mon.height) return 1;
            return (b.w * b.h) - (a.w * a.h);
        });
        return list;
    }

    Process {
        id: readProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monitors = Mon.parse(this.text);
                root.note = "Changes apply live, no reload. If a mode looks wrong, it reverts on its own after 12s.";
            }
        }
    }

    Process {
        id: applyProc
        property string out: ""
        property string mode: ""
        property string position: ""
        property real scale: 1
        command: ["sh", "-c",
            "sh \"$1\" apply \"$2\" \"$3\" \"$4\" \"$5\"",
            "sh", root.helper, out, mode, position, String(scale)]
        onExited: root.startCountdown()
    }

    Process {
        id: keepProc
        property string out: ""
        command: ["sh", "-c", "sh \"$1\" keep \"$2\"", "sh", root.helper, out]
    }

    /**
     * Builds the mode/position/scale for `mon` from its current picker state and
     * runs the helper's apply verb. Position holds the monitor's current x/y so a
     * resolution change never shifts the layout. Only availableModes Hz reach the
     * mode string, so an unsupported mode can never be requested.
     */
    function apply(mon, card) {
        if (root.pendingOut.length > 0)
            return;
        var res = root.resolutionsFor(mon)[card.resIndex];
        var hz = res.rates[card.rateIndex];
        applyProc.out = mon.name;
        applyProc.mode = res.w + "x" + res.h + "@" + hz;
        applyProc.position = mon.x + "x" + mon.y;
        applyProc.scale = card.pickScale;
        root.pendingOut = mon.name;
        applyProc.running = true;
    }

    function startCountdown() {
        root.countdown = 12;
        countTimer.start();
    }

    /**
     * Confirm the pending change: clear the helper's watchdog so it will not
     * revert, then persist by rewriting that output's block in monitors.lua.
     */
    function keep() {
        if (root.pendingOut.length === 0)
            return;
        keepProc.out = root.pendingOut;
        keepProc.running = true;
        var res = Mon.setMonitor(monitorsFile.text(), applyProc.out, applyProc.mode, applyProc.position, applyProc.scale);
        if (res.ok)
            writer.setText(res.text);
        cancelCountdown();
        root.note = "Saved. " + applyProc.out + " set to " + applyProc.mode + " · scale " + applyProc.scale;
    }

    /**
     * Stop the countdown and forget the pending output. Called on Keep, on the
     * watchdog-driven timeout (the helper has already reverted the live mode), and
     * when the surface closes.
     */
    function cancelCountdown() {
        countTimer.stop();
        root.countdown = 0;
        root.pendingOut = "";
    }

    Timer {
        id: countTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                root.cancelCountdown();
                readProc.running = true;
                root.note = "Reverted — the change was not confirmed in time.";
            }
        }
    }

    FileView {
        id: monitorsFile
        path: root.monitorsPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: writer
        path: root.monitorsPath
        atomicWrites: true
        printErrors: false
        onSaveFailed: (err) => {
            root.note = "Live mode kept, but writing monitors.lua failed.";
            console.log("display: write failed: " + err);
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "画"
            title: "DISPLAY"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 12 * root.s

            Repeater {
                model: root.monitors

                Rectangle {
                    id: card
                    required property var modelData

                    property int resIndex: 0
                    property int rateIndex: 0
                    property real pickScale: card.modelData.scale

                    readonly property var resolutions: root.resolutionsFor(card.modelData)
                    readonly property var rates: resolutions.length > 0 ? resolutions[Math.min(resIndex, resolutions.length - 1)].rates : []
                    readonly property bool pending: root.pendingOut === card.modelData.name

                    width: parent.width
                    radius: Motion.rTile * root.s
                    color: Theme.cardTop
                    border.width: 1
                    border.color: card.pending ? Qt.alpha(Theme.vermLit, 0.55) : Theme.hairSoft
                    implicitHeight: cardCol.implicitHeight + 22 * root.s
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    Component.onCompleted: card.syncToCurrent()

                    /**
                     * Seed the pickers from the monitor's live mode: the resolution
                     * whose WxH matches the current width/height, then the Hz nearest
                     * the current refresh within that resolution.
                     */
                    function syncToCurrent() {
                        for (var i = 0; i < resolutions.length; i++) {
                            if (resolutions[i].w === card.modelData.width && resolutions[i].h === card.modelData.height) {
                                card.resIndex = i;
                                break;
                            }
                        }
                        card.rateIndex = card.nearestRateIndex(card.modelData.refresh);
                        card.pickScale = card.modelData.scale;
                    }

                    function nearestRateIndex(hz) {
                        var best = 0;
                        var bestDiff = 1e9;
                        for (var i = 0; i < card.rates.length; i++) {
                            var d = Math.abs(card.rates[i] - hz);
                            if (d < bestDiff) { bestDiff = d; best = i; }
                        }
                        return best;
                    }

                    Column {
                        id: cardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 13 * root.s
                        anchors.rightMargin: 13 * root.s
                        anchors.topMargin: 11 * root.s
                        spacing: 9 * root.s

                        Text {
                            text: card.modelData.name
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12.5 * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: 0.3 * root.s
                        }

                        DisplayPicker {
                            width: parent.width
                            s: root.s
                            label: "Resolution"
                            options: card.resolutions.map(function (r, i) { return { label: r.w + "×" + r.h, value: i }; })
                            value: card.resIndex
                            open: root.openPicker === card.modelData.name + ":res"
                            onRequestToggle: root.openPicker = (root.openPicker === card.modelData.name + ":res" ? "" : card.modelData.name + ":res")
                            onPicked: (v) => {
                                card.resIndex = v;
                                card.rateIndex = card.nearestRateIndex(card.rates.length > 0 ? card.rates[0] : 60);
                                root.openPicker = "";
                            }
                        }

                        DisplayPicker {
                            width: parent.width
                            s: root.s
                            label: "Refresh"
                            options: card.rates.map(function (hz, i) { return { label: hz + "Hz", value: i }; })
                            value: Math.min(card.rateIndex, Math.max(0, card.rates.length - 1))
                            open: root.openPicker === card.modelData.name + ":rate"
                            onRequestToggle: root.openPicker = (root.openPicker === card.modelData.name + ":rate" ? "" : card.modelData.name + ":rate")
                            onPicked: (v) => {
                                card.rateIndex = v;
                                root.openPicker = "";
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8 * root.s

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64 * root.s
                                text: "Scale"
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: Font.Medium
                            }

                            SettingsSeg {
                                anchors.verticalCenter: parent.verticalCenter
                                s: root.s
                                options: root.scaleOptions
                                value: card.pickScale
                                onPicked: (v) => card.pickScale = v
                            }
                        }

                        Item {
                            width: parent.width
                            height: 30 * root.s

                            Rectangle {
                                id: applyBtn
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !card.pending && root.pendingOut.length === 0
                                width: applyLabel.implicitWidth + 28 * root.s
                                height: 28 * root.s
                                radius: 9 * root.s
                                color: applyArea.containsMouse ? Qt.alpha(Theme.onGlow, 0.34) : Qt.alpha(Theme.onGlow, 0.20)
                                border.width: 1
                                border.color: Qt.alpha(Theme.onGlow, applyArea.containsMouse ? 0.6 : 0.4)
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                Text {
                                    id: applyLabel
                                    anchors.centerIn: parent
                                    text: "Apply"
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: 10.5 * root.s
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.3 * root.s
                                }

                                MouseArea {
                                    id: applyArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.apply(card.modelData, card)
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: card.pending
                                spacing: 9 * root.s

                                Rectangle {
                                    id: keepBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: keepLabel.implicitWidth + 28 * root.s
                                    height: 28 * root.s
                                    radius: 9 * root.s
                                    color: keepArea.containsMouse ? Theme.vermLit : Theme.verm
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                                    Text {
                                        id: keepLabel
                                        anchors.centerIn: parent
                                        text: "Keep (" + root.countdown + ")"
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 10.5 * root.s
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: keepArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.keep()
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "reverts automatically if not kept"
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * root.s
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.note.length > 0
                text: root.note
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                lineHeight: 1.25
            }
        }

        Item { width: 1; height: 4 * root.s }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.pendingOut.length > 0
        z: 50
        onClicked: {}
    }
}
