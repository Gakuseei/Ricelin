pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 蓄 BATTERY surface: the percentage as hero, a time line, a charge meter and the stats UPower can report.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    implicitHeight: content.implicitHeight

    /** Seam dock at the head of the charge meter; the voids re-run mapToItem as size and charge change. */
    readonly property point chargeHead: {
        void root.width;
        void root.height;
        void Battery.frac;
        void meter.width;
        return meter.mapToItem(root, meter.width * Battery.frac, meter.height / 2);
    }

    ameForm: "seam"
    amePoint: chargeHead

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SurfaceHeader {
            s: root.s
            glyph: "蓄"
            title: "BATTERY"

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.stateLabel
                color: Battery.charging ? Theme.flameGlow : Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.label * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Theme.labelTracking * root.s
            }
        }

        Column {
            width: parent.width
            topPadding: Theme.sp.l * root.s
            bottomPadding: Theme.sp.m * root.s
            spacing: Theme.sp.s * root.s

            Text {
                id: pctText
                text: Battery.pct + "%"
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.cream)
                font.family: Theme.font
                font.pixelSize: 46 * root.s
                font.weight: Font.Bold
                font.letterSpacing: -1 * root.s
                font.features: { "tnum": 1 }
            }

            Text {
                readonly property string body: Battery.full
                    ? "Plugged in"
                    : (Battery.hasTime
                        ? Battery.timeStr + (Battery.charging ? " to full" : " remaining")
                        : "")
                visible: body.length > 0
                text: body
                color: Battery.charging ? Theme.flameCore : Theme.subtle
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: meter
            width: parent.width
            height: 3 * root.s
            radius: 1.5 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Battery.frac
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Battery.charging ? Theme.vermLit : Theme.vermDeep }
                    GradientStop { position: 1.0; color: Battery.charging ? Theme.flameGlow : Theme.vermLit }
                }
            }
        }

        Column {
            width: parent.width
            topPadding: Theme.sp.l * root.s
            spacing: Theme.sp.s * root.s

            component StatRow: Item {
                id: stat
                width: parent ? parent.width : 0
                height: vText.implicitHeight
                property string label: ""
                property string value: ""
                property bool warm: false

                Text {
                    anchors.left: parent.left
                    anchors.baseline: vText.baseline
                    text: stat.label
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.label * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Theme.labelTracking * root.s
                }

                Text {
                    id: vText
                    anchors.right: parent.right
                    text: stat.value
                    color: stat.warm ? Theme.flameGlow : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.body * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            StatRow {
                visible: Math.abs(Battery.rateW) >= 0.05
                label: "Rate"
                value: (Battery.rateW > 0 ? "+" : "−") + Math.abs(Battery.rateW).toFixed(1) + " W"
                warm: Battery.charging
            }

            StatRow {
                visible: Battery.healthSupported
                label: "Health"
                value: Battery.health + "%"
                warm: true
            }

            StatRow {
                visible: Battery.capacityWh >= 1
                label: "Capacity"
                value: Battery.capacityWh.toFixed(1) + " Wh"
            }
        }
    }
}
