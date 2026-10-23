pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "lib/setAnim.js" as SetAnim
import "Singletons"

/**
 * 動 ANIMATION: on/off, one master speed and the main bezier; animations.lua is read once per session, then the in-memory values win.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    /**
     * The curve handles stay mouse-only: a 2D drag has no single bump axis.
     */
    rows: {
        var r = [{ item: enabledRow, kind: "toggle", get: function () { return root.animOn; }, set: function (v) { root.animOn = v; root.writeEnabled(v); } }];
        if (root.animOn) {
            r.push({ item: speedRow, kind: "scrub", bump: function (d) { speedScrub.bump(d); } });
            r.push({ item: presetRow, kind: "seg", vals: root.presets.map(function (p) { return p.label; }), get: function () { return root.currentPreset; }, set: function (v) { root.applyPreset(v); } });
        }
        return r;
    }

    readonly property string animPath: Quickshell.env("HOME") + "/.config/hypr/modules/animations.lua"
    readonly property string mainCurve: "pillMorph"

    property bool animOn: true
    property real speed: 3
    property string animText: ""
    property bool loaded: false
    property var base: ({})

    /**
     * Bezier control points, read 0..1 (y may overshoot); derived from the handles.
     */
    property real cx1: 0.23
    property real cy1: 1.0
    property real cx2: 0.32
    property real cy2: 1.0

    readonly property var presets: [
        { label: "Smooth", x1: 0.23, y1: 1.0, x2: 0.32, y2: 1.0 },
        { label: "Snappy", x1: 0.15, y1: 0.0, x2: 0.1, y2: 1.0 },
        { label: "Linear", x1: 0.33, y1: 0.33, x2: 0.66, y2: 0.66 }
    ]

    /**
     * Label of the preset the live curve matches, or "" for a hand-shaped one.
     */
    readonly property string currentPreset: {
        for (var i = 0; i < presets.length; i++) {
            var p = presets[i];
            if (Math.abs(p.x1 - cx1) < 0.005 && Math.abs(p.y1 - cy1) < 0.005 && Math.abs(p.x2 - cx2) < 0.005 && Math.abs(p.y2 - cy2) < 0.005)
                return p.label;
        }
        return "";
    }

    function applyPreset(label) {
        for (var i = 0; i < root.presets.length; i++) {
            if (root.presets[i].label === label) {
                var p = root.presets[i];
                root.cx1 = p.x1; root.cy1 = p.y1; root.cx2 = p.x2; root.cy2 = p.y2;
                editor.syncHandles();
                root.writeCurve();
                return;
            }
        }
    }

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
     * One read per session: re-reading on open would race the writer and revert a fresh value.
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
    }

    function writeSpeed(v) {
        var r = SetAnim.setAllSpeeds(root.animText, String(v));
        if (!r.ok)
            return;
        root.animText = r.text;
        animWriter.setText(r.text);
    }

    function writeCurve() {
        var r = SetAnim.setCurvePoints(root.animText, root.mainCurve,
            root.cx1.toFixed(2), root.cy1.toFixed(2), root.cx2.toFixed(2), root.cy2.toFixed(2));
        if (!r.ok)
            return;
        root.animText = r.text;
        animWriter.setText(r.text);
    }

    FileView { id: animFile; path: root.animPath; blockLoading: true; printErrors: false }
    FileView { id: animWriter; path: root.animPath; atomicWrites: true; printErrors: false; onSaved: HyprReload.request() }

    component GroupLabel: SettingsLabel { s: root.s; leftPadding: Theme.sp.m * root.s }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SurfaceHeader {
            s: root.s
            glyph: "動"
            title: "ANIMATION"
            canBack: true
        }

        GroupLabel { text: "Motion" }

        SettingsRow {
            id: enabledRow
            surface: root
            name: "Enabled"
            sub: "Windows, workspaces and fades"
            icon: "sparkles"
            last: !root.animOn
            LinkToggle {
                s: root.s
                on: root.animOn
                onToggled: {
                    root.animOn = !root.animOn;
                    root.writeEnabled(root.animOn);
                }
            }
        }

        SettingsRow {
            id: speedRow
            surface: root
            name: "Speed"
            sub: "Higher is faster, for every animation"
            icon: "bolt"
            visible: root.animOn
            last: true
            ScrubValue {
                id: speedScrub
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
         * Bezier editor in unit curve space, y inverted; the handles are the source of truth for cx/cy.
         */
        Item {
            id: editor
            visible: root.animOn
            width: parent.width
            height: root.animOn ? square.height + Theme.sp.l * root.s : 0

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
                    radius: Theme.r.m * root.s
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
                    scale: h1drag.active && !Motion.calm ? 1.2 : (h1hover.hovered ? 1.1 : 1)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    HoverHandler { id: h1hover; cursorShape: Qt.SizeAllCursor }

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
                    scale: h2drag.active && !Motion.calm ? 1.2 : (h2hover.hovered ? 1.1 : 1)
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    HoverHandler { id: h2hover; cursorShape: Qt.SizeAllCursor }

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
                anchors.rightMargin: Theme.sp.m * root.s
                anchors.top: parent.top
                anchors.topMargin: Theme.sp.xs * root.s
                visible: editor.dirty
                width: 15 * root.s
                height: 15 * root.s
                name: "undo"
                color: revertArea.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
                stroke: 1.9

                MouseArea {
                    id: revertArea
                    anchors.fill: parent
                    anchors.margins: -Theme.sp.xs * root.s
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

        SettingsRow {
            id: presetRow
            surface: root
            name: "Preset"
            icon: "waves"
            visible: root.animOn
            last: true
            SettingsSeg {
                s: root.s
                options: root.presets.map(function (p) { return { label: p.label, value: p.label }; })
                value: root.currentPreset
                onPicked: (v) => root.applyPreset(v)
            }
        }
    }
}
