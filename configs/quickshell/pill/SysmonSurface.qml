pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 系 SYSTEM surface: dials for CPU, GPU and memory over a stripe of network, disk, swap and VRAM; the GPU parts drop without one.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight

    readonly property var dialKeys: Sysmon.hasGpu ? ["cpu", "gpu", "mem"] : ["cpu", "mem"]
    readonly property var cellKeys: Sysmon.hasVram ? ["net", "disk", "swap", "vram"] : ["net", "disk", "swap"]

    /** This surface's share of Sysmon.openCount, synced however the surface came to be open. */
    property bool counted: false
    function syncCount() {
        if (active !== counted) {
            Sysmon.openCount += active ? 1 : -1;
            counted = active;
        }
    }
    onActiveChanged: syncCount()
    Component.onCompleted: syncCount()
    Component.onDestruction: if (counted) Sysmon.openCount--

    /** The ember floats just above the header kanji, or left of the title when glyphs are off. */
    readonly property point soulPoint: {
        void root.width;
        void root.height;
        if (Flags.showGlyphs)
            return header.mapToItem(root, kanjiTm.advanceWidth / 2, (header.height - kanjiTm.height) / 2 - 3 * root.s);
        return header.mapToItem(root, -8 * root.s, header.height / 2);
    }

    TextMetrics {
        id: kanjiTm
        font.family: Theme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 16 * root.s
        text: "系"
    }

    ameForm: open ? "soul" : "off"
    amePoint: soulPoint

    component Dial: Item {
        id: dial

        property real arc: 0
        property string big: ""
        property string unit: ""
        property string sub: ""
        property string label: ""
        property bool shrink: false

        property real display: 0
        onArcChanged: display = arc
        Component.onCompleted: display = arc
        onDisplayChanged: face.requestPaint()
        Behavior on display { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

        width: 110 * root.s
        height: 110 * root.s

        Canvas {
            id: face
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var lw = 8 * root.s;
                var r = Math.min(width, height) / 2 - lw / 2 - root.s;
                var start = 135 * Math.PI / 180;
                var full = 270 * Math.PI / 180;
                ctx.lineCap = "round";
                ctx.lineWidth = lw;
                ctx.strokeStyle = Theme.threadBg;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + full, false);
                ctx.stroke();
                var v = Math.max(0, Math.min(100, dial.display));
                if (v > 0.5) {
                    var diag = r * 0.7071;
                    var grad = ctx.createLinearGradient(cx - diag, cy + diag, cx + diag, cy - diag);
                    grad.addColorStop(0, Theme.vermBurn);
                    grad.addColorStop(0.35, Theme.vermBurn);
                    grad.addColorStop(1, Theme.vermLit);
                    ctx.strokeStyle = grad;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, start, start + full * v / 100, false);
                    ctx.stroke();
                }
            }
        }

        /** The value alone owns the centre so any digit count stays on the eye line; label and sub hang below. */
        Row {
            id: bigRow
            anchors.centerIn: parent
            /** Ring gap is at the bottom, so its optical middle sits above the hole centre; lift the value there. */
            anchors.verticalCenterOffset: -12 * root.s
            spacing: 1 * root.s

            Text {
                id: bigText
                text: dial.big
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: (dial.shrink ? 16 : 20) * root.s
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.5 * root.s
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.baseline: bigText.baseline
                visible: dial.unit.length > 0
                text: dial.unit
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.Bold
            }
        }

        Column {
            anchors.top: bigRow.bottom
            anchors.topMargin: Theme.sp.xxs * root.s
            anchors.horizontalCenter: bigRow.horizontalCenter
            spacing: Theme.sp.xxs * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.label
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.label * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.labelTracking * root.s
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.sub
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
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
            id: header
            s: root.s
            glyph: "系"
            title: "System"

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Sysmon.uptime
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        Item { width: 1; height: Theme.sp.l * root.s }

        Item {
            width: parent.width
            height: 110 * root.s

            Repeater {
                model: root.dialKeys

                Dial {
                    required property int index
                    required property var modelData
                    readonly property string key: modelData
                    readonly property int val: key === "cpu" ? Sysmon.cpu : key === "gpu" ? Sysmon.gpu : Sysmon.memPct

                    x: root.dialKeys.length > 1
                        ? index * (parent.width - width) / (root.dialKeys.length - 1)
                        : (parent.width - width) / 2

                    arc: val
                    big: key === "mem" ? Sysmon.memUsedGb.toFixed(1) : "" + val
                    unit: key === "mem" ? "" : "%"
                    shrink: key !== "mem" && val >= 100
                    label: key
                    sub: key === "cpu" ? (Sysmon.cpuTemp >= 0 ? Sysmon.cpuTemp + "°" : "")
                        : key === "gpu" ? (Sysmon.gpuTemp >= 0 ? Sysmon.gpuTemp + "°" : "")
                        : "/ " + Sysmon.memTotalGb.toFixed(0) + " GB"
                }
            }
        }

        Item { width: 1; height: Theme.sp.l * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: Theme.sp.m * root.s }

        Item {
            width: parent.width
            height: 30 * root.s

            Repeater {
                model: root.cellKeys

                Item {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property string key: modelData

                    width: parent.width / root.cellKeys.length
                    height: parent.height
                    x: index * width

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 2 * root.s
                        anchors.bottomMargin: 2 * root.s
                        height: parent.height - 4 * root.s
                        width: 1
                        visible: cell.index > 0
                        color: Theme.hairSoft
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.sp.xs * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.key === "net" ? "Net · MB/s"
                                : cell.key === "disk" ? "Disk · %"
                                : cell.key === "swap" ? "Swap · GB"
                                : "VRAM · GB"
                            color: Theme.textFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.label * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: Theme.labelTracking * root.s
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.sp.s * root.s
                            visible: cell.key === "net"

                            Text {
                                text: "↓" + Sysmon.netDown.toFixed(1)
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: "↑" + Sysmon.netUp.toFixed(1)
                                color: Theme.vermLit
                                font.family: Theme.font
                                font.pixelSize: Theme.fs.body * root.s
                                font.weight: Font.ExtraBold
                                font.features: { "tnum": 1 }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: cell.key !== "net"
                            text: cell.key === "disk" ? "" + Sysmon.diskPct
                                : cell.key === "swap" ? Sysmon.swapUsedGb.toFixed(1)
                                : Sysmon.vramUsedGb.toFixed(1) + " / " + Sysmon.vramTotalGb.toFixed(0)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: Theme.fs.body * root.s
                            font.weight: Font.ExtraBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
