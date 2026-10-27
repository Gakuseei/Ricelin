import QtQuick
import Quickshell.Networking
import "Singletons"

/**
 * The hover bar: workspaces, clock and date, and the status icons that open their surfaces.
 */
Face {
    id: face

    mode: "hover"
    exitMs: 90
    visible: true

    readonly property real s: host.s
    readonly property alias rowWidth: hoverRow.implicitWidth

    /**
     * Ame's dock while hovered: under the hovered icon or dot, else under the active workspace.
     */
    readonly property point soulPoint: {
        void host.width;
        void host.height;
        const drop = 12 * s;
        const it = host.soulItem;
        if (it)
            return it.mapToItem(face, it.width / 2, it.height + drop * 0.55);
        if (host.soulWsIndex >= 0) {
            void ws.activeName;
            void ws.width;
            const p = ws.mapToItem(face, ws.slotCenterX(host.soulWsIndex), ws.height / 2);
            return Qt.point(p.x, p.y + drop);
        }
        return ws.mapToItem(face, ws.activeDotPoint.x, ws.activeDotPoint.y + drop);
    }

    Row {
        id: hoverRow
        anchors.centerIn: parent
        spacing: 20 * face.s

        Workspaces {
            id: ws
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            screenName: face.host.screenName
            s: face.s
            gap: 8 * face.s
            enabled: face.live
            onHoverIndexChanged: if (hoverIndex >= 0) {
                face.host.soulItem = null;
                face.host.soulWsIndex = hoverIndex;
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22 * face.s
            color: Theme.hair
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: hoverClock.implicitWidth
            height: hoverClock.implicitHeight

            Column {
                id: hoverClock
                anchors.centerIn: parent
                spacing: 2 * face.s
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.hhmm
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 18 * face.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.date
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 8.5 * face.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * face.s
                }
            }

            MouseArea {
                anchors.centerIn: parent
                width: hoverClock.implicitWidth + 22 * face.s
                height: hoverClock.implicitHeight + 10 * face.s
                enabled: face.live
                cursorShape: Qt.PointingHandCursor
                onClicked: face.host.requestSurface("calendar")
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22 * face.s
            color: Theme.hair
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * face.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Weather.ready
                spacing: 5 * face.s

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    enabled: face.live
                }
                TapHandler {
                    enabled: face.live
                    onTapped: face.host.requestSurface("calendar")
                }

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * face.s
                    height: 16 * face.s
                    name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                    color: Theme.subtle
                    stroke: 1.8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.tempNow + "°"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 12.5 * face.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            MinimizedTray {
                id: minimized
                anchors.verticalCenter: parent.verticalCenter
                s: face.s
                screenName: face.host.screenName
                enabled: face.live
                visible: count > 0
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: minimized.count > 0
                width: 1
                height: 14 * face.s
                color: Theme.hair
                opacity: 0.7
            }

            Tray {
                anchors.verticalCenter: parent.verticalCenter
                s: face.s
                barWindow: face.host.barWindow
                enabled: face.live
            }

            Item {
                id: dndIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.dnd
                width: 16 * face.s
                height: 16 * face.s

                GlyphIcon {
                    anchors.fill: parent
                    name: "dnd"
                    color: Theme.vermLit
                    stroke: 1.7
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Net.wifiDev !== null || Net.btAdapter !== null || Battery.present
                spacing: 12 * face.s

                HoverIcon {
                    host: face.host
                    surface: "wifi"
                    visible: Net.wifiDev !== null
                    implicitWidth: 15 * face.s
                    implicitHeight: 15 * face.s
                    onRightClicked: Net.toggleWifi()

                    WifiGlyph {
                        anchors.centerIn: parent
                        s: face.s
                        level: Net.wifiLevel
                        on: Net.wifiOn
                        stroke: 1.7
                    }
                }

                HoverIcon {
                    id: btIcon
                    host: face.host
                    surface: "bt"
                    visible: Net.btAdapter !== null
                    implicitWidth: 15 * face.s + (btLowPct.visible ? btLowPct.implicitWidth + 4 * face.s : 0)
                    implicitHeight: 15 * face.s
                    onRightClicked: Net.toggleBt()

                    GlyphIcon {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * face.s
                        height: 15 * face.s
                        name: "bluetooth"
                        color: btIcon.hovered ? Theme.cream
                            : (Peripherals.connectedCount > 0 ? Theme.vermLit
                            : (Net.btOn ? Theme.iconDim : Qt.alpha(Theme.iconDim, 0.4)))
                        stroke: 1.7
                    }

                    Text {
                        id: btLowPct
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Peripherals.lowestPct >= 0 && Peripherals.lowestPct <= Peripherals.lowAt
                        text: Peripherals.lowestPct + "%"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 11 * face.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                HoverIcon {
                    host: face.host
                    surface: "battery"
                    visible: Battery.present
                    implicitWidth: battPct.implicitWidth
                    implicitHeight: 17 * face.s

                    Text {
                        id: battPct
                        anchors.centerIn: parent
                        text: Battery.pct + "%"
                        color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                        font.family: Theme.font
                        font.pixelSize: 13 * face.s
                        font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
            }

            HoverIcon {
                host: face.host
                surface: "link"
                glyph: "inbox"

                Rectangle {
                    visible: Notifs.unread > 0
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2 * face.s
                    anchors.rightMargin: -2 * face.s
                    width: 5 * face.s
                    height: 5 * face.s
                    radius: width / 2
                    color: Theme.flameGlow
                }
            }

            HoverIcon {
                host: face.host
                surface: "mixer"
                glyph: "mixer"
            }

            HoverIcon {
                host: face.host
                surface: "sound"
                glyph: "music"
                tint: Sound.eq ? Theme.vermLit : Theme.iconDim
            }

            HoverIcon {
                host: face.host
                surface: "sysmon"
                glyph: "monitor"
            }

            HoverIcon {
                host: face.host
                surface: "recorder"
                glyph: ScreenRec.recording ? "" : "video"
                onRightClicked: if (ScreenRec.recording) ScreenRec.stop()
                onDoubleClicked: if (ScreenRec.recording) ScreenRec.stop()

                Rectangle {
                    anchors.centerIn: parent
                    visible: ScreenRec.recording
                    width: 12 * face.s
                    height: 12 * face.s
                    radius: width / 2
                    color: Theme.verm
                    SequentialAnimation on opacity {
                        running: ScreenRec.recording && face.live && !Motion.calm
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                    }
                }
            }

            HoverIcon {
                host: face.host
                surface: "settings"
                glyph: "cog"
                stroke: 1.6
            }

            HoverIcon {
                host: face.host
                surface: "power"
                glyph: "shutdown"
            }
        }
    }
}
