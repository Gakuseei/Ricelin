pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "lib/setAnim.js" as SetAnim
import "Singletons"

/**
 * 動 ANIMATION sub-surface: toggles Hyprland animations, sets one master speed
 * across every leaf, and shapes the main motion curve by dragging its two bezier
 * control points. animations.lua is read once per pill session (first seed);
 * after that the in-memory properties are the single source of truth, so
 * reopening the tab never re-reads — that would race the writer FileView on the
 * same path and revert a freshly written value. Each change rewrites the file
 * immediately and debounces the hyprctl reload through a Timer, so a fast speed
 * scrub still lands its final value with exactly one reload. The speed scrub and
 * the curve carry a revert baseline snapshotted on that first seed, restored by
 * an undo glyph; it survives leaving and reopening the tab so a curve change
 * stays revertable while you go watch it play. The editor's handle positions are
 * the source of truth — the curve point properties derive from them — so
 * dragging a handle never fights a binding. Reached from the settings index;
 * morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property string animPath: Quickshell.env("HOME") + "/.config/hypr/modules/animations.lua"
    readonly property string mainCurve: "easeOutQuint"

    property bool animOn: true
    property real speed: 3
    property string animText: ""
    property bool loaded: false
    property var base: ({})

    /** Bezier control points, read 0..1 (y may overshoot); derived from the handles. */
    property real cx1: 0.23
    property real cy1: 1.0
    property real cx2: 0.32
    property real cy2: 1.0

    readonly property var presets: [
        { label: "Smooth", x1: 0.23, y1: 1.0, x2: 0.32, y2: 1.0 },
        { label: "Snappy", x1: 0.15, y1: 0.0, x2: 0.1, y2: 1.0 },
        { label: "Linear", x1: 0.33, y1: 0.33, x2: 0.66, y2: 0.66 }
    ]

    onActiveChanged: {
        if (active) {
            if (!root.loaded) {
                animFile.reload();
                seed();
            }
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Reads the controls from animations.lua once per pill session. After this
     * the in-memory properties are the source of truth, so reopening the tab
     * never re-reads (which would race the writer FileView on the same path and
     * revert a freshly written value). Also snapshots the revert baseline and
     * marks the session loaded.
     */
    function seed() {
        root.animText = animFile.text();
        var t = root.animText;

        root.animOn = SetAnim.getEnabled(t) === "true";
        var sp = parseFloat(SetAnim.getLeafSpeed(t, "global"));
        root.speed = isNaN(sp) ? 3 : sp;

        var pts = SetAnim.getCurvePoints(t, root.mainCurve);
        if (pts) {
            root.cx1 = pts[0];
            root.cy1 = pts[1];
            root.cx2 = pts[2];
            root.cy2 = pts[3];
        }
        root.base = { speed: root.speed, cx1: root.cx1, cy1: root.cy1, cx2: root.cx2, cy2: root.cy2 };
        root.loaded = true;
    }

    function writeEnabled(on) {
        var r = SetAnim.setEnabled(root.animText, on ? "true" : "false");
        if (!r.ok)
            return;
        root.animText = r.text;
        animWriter.setText(r.text);
        reloadTimer.restart();
    }

    function writeSpeed(v) {
        var r = SetAnim.setAllSpeeds(root.animText, String(v));
        if (!r.ok)
            return;
        root.animText = r.text;
        animWriter.setText(r.text);
        reloadTimer.restart();
    }

    function writeCurve() {
        var r = SetAnim.setCurvePoints(root.animText, root.mainCurve,
            root.cx1.toFixed(2), root.cy1.toFixed(2), root.cx2.toFixed(2), root.cy2.toFixed(2));
        if (!r.ok)
            return;
        root.animText = r.text;
        animWriter.setText(r.text);
        reloadTimer.restart();
    }

    FileView { id: animFile; path: root.animPath; blockLoading: true; printErrors: false }
    FileView { id: animWriter; path: root.animPath; atomicWrites: true; printErrors: false }
    Process { id: reloadProc; command: ["setsid", "-f", "sh", "-c", "sleep 0.3; hyprctl reload"] }
    Timer { id: reloadTimer; interval: 250; repeat: false; onTriggered: reloadProc.running = true }

    component GroupLabel: Text {
        topPadding: 16 * root.s
        bottomPadding: 6 * root.s
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    component FieldRow: Item {
        id: frow
        property string label: ""
        property string caption: ""
        default property alias control: ctrl.data

        readonly property bool expanded: fhover.hovered
        width: parent ? parent.width : 0
        height: 30 * root.s + (expanded ? 14 * root.s : 0)
        clip: true
        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        HoverHandler { id: fhover }

        Text {
            id: lbl
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 8 * root.s
            text: frow.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
        }
        Text {
            anchors.left: parent.left
            anchors.top: lbl.bottom
            anchors.topMargin: 2 * root.s
            visible: frow.expanded && frow.caption.length > 0
            text: frow.caption
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.Medium
        }
        Item {
            id: ctrl
            anchors.right: parent.right
            anchors.verticalCenter: lbl.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
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
            glyph: "動"
            title: "ANIMATION"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            GroupLabel { text: "Motion" }

            FieldRow {
                label: "Enabled"
                caption: "Animate windows, workspaces and fades"
                LinkToggle {
                    s: root.s
                    on: root.animOn
                    onToggled: {
                        root.animOn = !root.animOn;
                        root.writeEnabled(root.animOn);
                    }
                }
            }

            FieldRow {
                label: "Speed"
                caption: "Higher is faster, applied to every animation"
                visible: root.animOn
                ScrubValue {
                    s: root.s
                    value: root.speed
                    openValue: root.base.speed
                    from: 1; to: 10; step: 0.5; decimals: 1
                    onEdited: v => {
                        root.speed = v;
                        root.writeSpeed(v);
                    }
                }
            }

            GroupLabel {
                text: "Curve"
                visible: root.animOn
            }

            /**
             * Bezier editor. The square maps unit curve-space (0,0 bottom-left to
             * 1,1 top-right) to pixels with y inverted; the two handles are the
             * source of truth and the cx/cy properties read back from them. An undo
             * glyph appears whenever the live points drift from the on-open snapshot.
             */
            Item {
                id: editor
                visible: root.animOn
                width: parent.width
                height: visible ? square.height + 18 * root.s : 0

                readonly property real es: 150 * root.s
                readonly property real r: 7 * root.s
                readonly property bool dirty: root.base.cx1 !== undefined
                    && (root.cx1 !== root.base.cx1 || root.cy1 !== root.base.cy1
                        || root.cx2 !== root.base.cx2 || root.cy2 !== root.base.cy2)

                function pxX(v) { return v * editor.es; }
                function pxY(v) { return editor.es - v * editor.es; }

                function commitFromHandles() {
                    root.cx1 = Math.max(0, Math.min(1, (h1.x + editor.r) / editor.es));
                    root.cy1 = 1 - (h1.y + editor.r) / editor.es;
                    root.cx2 = Math.max(0, Math.min(1, (h2.x + editor.r) / editor.es));
                    root.cy2 = 1 - (h2.y + editor.r) / editor.es;
                }

                function syncHandles() {
                    h1.x = editor.pxX(root.cx1) - editor.r;
                    h1.y = editor.pxY(root.cy1) - editor.r;
                    h2.x = editor.pxX(root.cx2) - editor.r;
                    h2.y = editor.pxY(root.cy2) - editor.r;
                }

                onVisibleChanged: if (visible) syncHandles()
                Component.onCompleted: syncHandles()
                Connections {
                    target: root
                    function onBaseChanged() { editor.syncHandles(); }
                }

                Item {
                    id: square
                    width: editor.es
                    height: editor.es
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 10 * root.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.hairSoft
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.cream, 0.12)
                            strokeWidth: 1
                            fillColor: "transparent"
                            startX: 0; startY: editor.es
                            PathLine { x: editor.es; y: 0 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.onGlow, 0.35)
                            strokeWidth: 1.2
                            fillColor: "transparent"
                            startX: 0; startY: editor.es
                            PathLine { x: editor.pxX(root.cx1); y: editor.pxY(root.cy1) }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(Theme.onGlow, 0.35)
                            strokeWidth: 1.2
                            fillColor: "transparent"
                            startX: editor.es; startY: 0
                            PathLine { x: editor.pxX(root.cx2); y: editor.pxY(root.cy2) }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Theme.onGlow
                            strokeWidth: 2.4 * root.s
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 0; startY: editor.es
                            PathCubic {
                                control1X: editor.pxX(root.cx1); control1Y: editor.pxY(root.cy1)
                                control2X: editor.pxX(root.cx2); control2Y: editor.pxY(root.cy2)
                                x: editor.es; y: 0
                            }
                        }
                    }

                    Rectangle {
                        id: h1
                        width: 2 * editor.r
                        height: 2 * editor.r
                        radius: editor.r
                        color: h1drag.active ? Theme.bright : Theme.cream
                        border.width: 2
                        border.color: Theme.onGlow

                        DragHandler {
                            id: h1drag
                            target: h1
                            xAxis.minimum: -editor.r
                            xAxis.maximum: editor.es - editor.r
                            yAxis.minimum: -editor.r - 0.35 * editor.es
                            yAxis.maximum: editor.es - editor.r + 0.35 * editor.es
                            onActiveChanged: if (!active) root.writeCurve()
                        }
                        onXChanged: if (h1drag.active) editor.commitFromHandles()
                        onYChanged: if (h1drag.active) editor.commitFromHandles()
                    }

                    Rectangle {
                        id: h2
                        width: 2 * editor.r
                        height: 2 * editor.r
                        radius: editor.r
                        color: h2drag.active ? Theme.bright : Theme.cream
                        border.width: 2
                        border.color: Theme.onGlow

                        DragHandler {
                            id: h2drag
                            target: h2
                            xAxis.minimum: -editor.r
                            xAxis.maximum: editor.es - editor.r
                            yAxis.minimum: -editor.r - 0.35 * editor.es
                            yAxis.maximum: editor.es - editor.r + 0.35 * editor.es
                            onActiveChanged: if (!active) root.writeCurve()
                        }
                        onXChanged: if (h2drag.active) editor.commitFromHandles()
                        onYChanged: if (h2drag.active) editor.commitFromHandles()
                    }
                }

                GlyphIcon {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4 * root.s
                    visible: editor.dirty
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "undo"
                    color: revertArea.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
                    stroke: 1.9

                    MouseArea {
                        id: revertArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.cx1 = root.base.cx1; root.cy1 = root.base.cy1;
                            root.cx2 = root.base.cx2; root.cy2 = root.base.cy2;
                            editor.syncHandles();
                            root.writeCurve();
                        }
                    }
                }
            }

            FieldRow {
                label: "Preset"
                caption: "Drop in a ready-made curve"
                visible: root.animOn
                SettingsSeg {
                    s: root.s
                    options: root.presets.map(function (p) { return { label: p.label, value: p.label }; })
                    value: ""
                    onPicked: (v) => {
                        for (var i = 0; i < root.presets.length; i++) {
                            if (root.presets[i].label === v) {
                                var p = root.presets[i];
                                root.cx1 = p.x1; root.cy1 = p.y1; root.cx2 = p.x2; root.cy2 = p.y2;
                                editor.syncHandles();
                                root.writeCurve();
                                break;
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
