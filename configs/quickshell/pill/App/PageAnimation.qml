pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/setAnim.js" as SetAnim
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "animation"

    readonly property string animPath: Quickshell.env("HOME") + "/.config/hypr/modules/animations.lua"
    readonly property string mainCurve: "pillMorph"
    property string animText: ""

    property bool animOn: true
    /** Hyprland's speed is a duration in tenths of a second: 4.2 means 420 ms, so lower is quicker. */
    property real speed: 4.2
    property real cx1: 0.16
    property real cy1: 1
    property real cx2: 0.3
    property real cy2: 1
    property var customPts: null

    readonly property var defaults: ({ animOn: true, speed: 4.2, curve: [0.16, 1, 0.3, 1] })

    readonly property var presets: [
        { label: "Smooth", value: "smooth", pts: [0.16, 1, 0.3, 1] },
        { label: "Snappy", value: "snappy", pts: [0.15, 0, 0.1, 1] },
        { label: "Linear", value: "linear", pts: [0.33, 0.33, 0.66, 0.66] }
    ]

    readonly property var pts: [cx1, cy1, cx2, cy2]
    readonly property string preset: {
        for (let i = 0; i < presets.length; i++) {
            const p = presets[i].pts;
            if (Math.abs(p[0] - cx1) < 0.005 && Math.abs(p[1] - cy1) < 0.005 && Math.abs(p[2] - cx2) < 0.005 && Math.abs(p[3] - cy2) < 0.005)
                return presets[i].value;
        }
        return "custom";
    }
    readonly property string presetLabel: preset === "custom" ? "Custom" : presets.find(p => p.value === preset).label
    readonly property int durationMs: Math.round(speed * 100)

    Component.onCompleted: seed()

    function seed() {
        const t = animFile.text();
        animText = t;
        animOn = SetAnim.getEnabled(t) !== "false";
        const sp = parseFloat(SetAnim.getLeafSpeed(t, "global"));
        speed = isNaN(sp) ? defaults.speed : sp;
        const p = SetAnim.getCurvePoints(t, mainCurve);
        if (p)
            setPoints(p);
        if (preset === "custom")
            customPts = pts.slice();
    }

    function setPoints(p) {
        cx1 = p[0];
        cy1 = p[1];
        cx2 = p[2];
        cy2 = p[3];
    }

    function save(text) {
        animText = text;
        animWriter.put(text);
    }

    function writeEnabled(on) {
        animOn = on;
        const r = SetAnim.setEnabled(animText, on ? "true" : "false");
        if (r.ok)
            save(r.text);
    }

    function writeSpeed(ms) {
        speed = Math.round(ms / 10) / 10;
        const r = SetAnim.setAllSpeeds(animText, String(speed));
        if (r.ok)
            save(r.text);
    }

    function writeCurve() {
        const r = SetAnim.setCurvePoints(animText, mainCurve, cx1.toFixed(2), cy1.toFixed(2), cx2.toFixed(2), cy2.toFixed(2));
        if (r.ok)
            save(r.text);
    }

    function pickPreset(v) {
        if (v === "custom") {
            if (customPts) {
                setPoints(customPts);
                writeCurve();
            } else {
                page.reveal("animation.editor");
                App.toast("Drag the handles to make your own curve");
            }
            return;
        }
        const p = presets.find(x => x.value === v);
        if (!p)
            return;
        if (preset === "custom")
            customPts = pts.slice();
        setPoints(p.pts);
        writeCurve();
    }

    function reset() {
        const d = defaults;
        let t = animText;
        let r = SetAnim.setEnabled(t, String(d.animOn));
        if (r.ok)
            t = r.text;
        r = SetAnim.setAllSpeeds(t, String(d.speed));
        if (r.ok)
            t = r.text;
        r = SetAnim.setCurvePoints(t, mainCurve, d.curve[0].toFixed(2), d.curve[1].toFixed(2), d.curve[2].toFixed(2), d.curve[3].toFixed(2));
        if (r.ok)
            t = r.text;
        animOn = d.animOn;
        speed = d.speed;
        setPoints(d.curve);
        if (t !== animText)
            save(t);
    }

    FileView {
        id: animFile
        path: page.animPath
        blockLoading: true
        printErrors: false
    }

    Writer {
        id: animWriter
        path: page.animPath
        onWritten: HyprReload.request()
    }

    /** Atomic writer that keeps one write in flight, so a quick second edit can never land before the first. */
    component Writer: FileView {
        property string queued: ""
        property bool busy: false
        property bool more: false
        signal written()
        preload: false
        atomicWrites: true
        printErrors: false
        function put(t) {
            if (busy) {
                queued = t;
                more = true;
                return;
            }
            busy = true;
            setText(t);
        }
        function settle() {
            busy = false;
            if (more) {
                more = false;
                put(queued);
            } else {
                written();
            }
        }
        onSaved: Qt.callLater(settle)
        onSaveFailed: Qt.callLater(settle)
    }

    Timer {
        id: replay
        interval: 380
        onTriggered: preview.play()
    }
    onPtsChanged: if (curveEditor.dragging === 0) replay.restart()
    onDurationMsChanged: replay.restart()
    onAnimOnChanged: replay.restart()
    Connections {
        target: Motion
        function onCalmChanged() { replay.restart(); }
    }

    Text {
        x: 12 * page.s
        width: parent.width - 24 * page.s
        topPadding: 16 * page.s
        visible: HyprReload.failed
        text: "Hyprland could not reload. Changes are saved but not applied yet."
        color: Theme.danger
        wrapMode: Text.WordWrap
        font.family: Theme.font
        font.pixelSize: 12 * page.s
    }

    AppGroup {
        title: "Motion"

        AppRow {
            label: "Animations"
            sub: "Windows, workspaces and fades move instead of jumping"
            key: "animation.enabled"
            clickable: true
            onClicked: animToggle.flip()
            AppToggle {
                id: animToggle
                checked: page.animOn
                onToggled: (on) => page.writeEnabled(on)
            }
        }
        AppRow {
            label: "Duration"
            sub: "How long each move takes. Lower is quicker"
            key: "animation.speed"
            enabled: page.animOn
            opacity: enabled ? 1 : 0.45
            AppSlider {
                from: 100; to: 1000; step: 10; unit: "ms"
                value: page.durationMs
                onMoved: (v) => page.writeSpeed(v)
            }
        }
    }

    AppGroup {
        title: "Curve"
        enabled: page.animOn
        opacity: enabled ? 1 : 0.45

        AppRow {
            label: "Motion curve"
            sub: "How a move speeds up and settles"
            key: "animation.curve"
            AppSeg {
                options: page.presets.map(p => ({ label: p.label, value: p.value })).concat([{ label: "Custom", value: "custom" }])
                value: page.preset
                onPicked: (v) => page.pickPreset(v)
            }
        }

        AppRow {
            id: editorRow
            label: "Curve editor"
            sub: "Drag the two handles. The preview replays with your curve and duration"
            key: "animation.editor"
            block: true

            Item {
                id: editorBox
                readonly property real gap: 20 * page.s
                width: parent.width
                height: curveEditor.height + controls.height + 12 * page.s

                PageAnimationCurve {
                    id: curveEditor
                    clock: preview.clock
                    x1: page.cx1
                    y1: page.cy1
                    x2: page.cx2
                    y2: page.cy2
                    onEdited: (a, b, c, d) => page.setPoints([a, b, c, d])
                    onReleased: {
                        if (page.preset === "custom")
                            page.customPts = page.pts.slice();
                        page.writeCurve();
                        replay.restart();
                    }
                }

                PageAnimationPreview {
                    id: preview
                    x: curveEditor.width + editorBox.gap
                    height: curveEditor.height
                    width: Math.min(editorBox.width - x, height * 1.6)
                    curve: page.pts
                    duration: page.durationMs
                    animate: page.animOn
                }

                Row {
                    id: controls
                    y: curveEditor.height + 12 * page.s
                    spacing: 12 * page.s

                    AppButton {
                        anchors.verticalCenter: parent.verticalCenter
                        small: true
                        icon: "play"
                        text: "Play"
                        onClicked: preview.play()
                    }
                    AppSeg {
                        anchors.verticalCenter: parent.verticalCenter
                        small: true
                        options: [{ label: "1×", value: false }, { label: "¼×", value: true }]
                        value: preview.slow
                        onPicked: (v) => {
                            preview.slow = v;
                            preview.play();
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1 * page.s

                        Text {
                            text: !page.animOn ? "Animations are off, windows appear at once"
                                : preview.step.length > 0 ? preview.step
                                : page.presetLabel + " · " + page.durationMs + " ms per move"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * page.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            text: "cubic-bezier(" + page.pts.map(v => v.toFixed(2)).join(", ") + ")"
                            color: Theme.textFaint
                            font.family: "JetBrains Mono"
                            font.pixelSize: 10.5 * page.s
                        }
                    }
                }
            }
        }
    }
}
