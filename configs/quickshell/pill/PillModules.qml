pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Every pill module by id, sized for the row it sits in (rest or hover) with clicks routed through that row.
 */
QtObject {
    id: mods

    required property Item row
    readonly property real s: row.s
    readonly property bool hover: row.hover

    readonly property var byId: ({
        glyph: glyph, clock: clock, date: date, clockdate: clockdate, workspaces: workspaces,
        weather: weather, battery: battery, musicbars: musicbars, live: live, minimized: minimized,
        tray: tray, dnd: dnd, wifi: wifi, bt: bt, inbox: inbox, mixer: mixer, sound: sound,
        sysmon: sysmon, recorder: recorder, settings: settings, power: power
    })

    /**
     * The rest glyph in its outline style, a clock icon without glyphs, or live music bars while something plays.
     */
    readonly property Component glyph: Component {
        Item {
            id: g

            readonly property bool barsOn: Flags.musicViz && Cava.active
            readonly property real k: mods.hover ? 17 / 15 : 1

            implicitWidth: fill.implicitWidth
            implicitHeight: fill.implicitHeight
            Component.onCompleted: mods.row.glyphItem = g

            Text {
                anchors.fill: parent
                opacity: (Flags.showGlyphs && !g.barsOn) ? 1 : 0
                text: fill.text
                color: "transparent"
                font: fill.font
                style: Text.Outline
                styleColor: Qt.alpha(Theme.vermLit, mods.row.glyphOutline)
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            Text {
                id: fill
                opacity: (Flags.showGlyphs && !g.barsOn) ? 1 : 0
                text: Flags.restGlyph.length > 0 ? Flags.restGlyph : "時"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 15 * mods.s * g.k
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            GlyphIcon {
                anchors.centerIn: parent
                opacity: (!Flags.showGlyphs && !g.barsOn) ? 1 : 0
                width: 17 * mods.s * g.k
                height: width
                name: "clock"
                color: Theme.cream
                stroke: 1.7
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            MusicBars {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: fill.baseline
                s: mods.s
                opacity: g.barsOn ? 1 : 0
                scale: g.barsOn ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }
    }

    readonly property Component clock: Component {
        Text {
            text: Clock.hhmm
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: (mods.hover ? 18 : 16) * mods.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    readonly property Component date: Component {
        Text {
            text: Clock.date
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: (mods.hover ? 12.5 : 14) * mods.s
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    readonly property Component clockdate: Component {
        Item {
            implicitWidth: stack.implicitWidth
            implicitHeight: stack.implicitHeight

            Column {
                id: stack
                anchors.centerIn: parent
                spacing: (mods.hover ? 2 : 1) * mods.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.hhmm
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: (mods.hover ? 18 : 13.5) * mods.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Clock.date
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: (mods.hover ? 9.5 : 8) * mods.s
                    font.weight: Font.Medium
                    font.letterSpacing: 0.2 * mods.s
                }
            }

            MouseArea {
                anchors.centerIn: parent
                width: stack.implicitWidth + 22 * mods.s
                height: stack.implicitHeight + 10 * mods.s
                enabled: mods.row.live
                cursorShape: Qt.PointingHandCursor
                onClicked: mods.row.open("calendar")
            }
        }
    }

    readonly property Component workspaces: Component {
        Workspaces {
            id: w
            screenName: mods.row.screenName
            s: mods.s
            gap: (mods.hover ? 8 : 6) * mods.s
            fontPx: (mods.hover ? 12 : 11) * mods.s
            style: Flags.wsStyle
            show: Flags.wsShow
            scroll: Flags.wsScroll
            actions: mods.row.actions
            enabled: mods.row.live
            onHoverIndexChanged: mods.row.wsHover(hoverIndex)
            Component.onCompleted: mods.row.wsItem = w
        }
    }

    readonly property Component weather: Component {
        Item {
            readonly property bool shown: Weather.ready
            implicitWidth: wx.implicitWidth
            implicitHeight: wx.implicitHeight

            Row {
                id: wx
                spacing: 5 * mods.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: (mods.hover ? 16 : 15) * mods.s
                    height: width
                    name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                    color: Theme.subtle
                    stroke: 1.8
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.tempNow + "°"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: (mods.hover ? 12.5 : 14) * mods.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: mods.row.live
                cursorShape: Qt.PointingHandCursor
                onClicked: mods.row.open("calendar")
            }
        }
    }

    readonly property Component battery: Component {
        HoverIcon {
            row: mods.row
            iconId: "battery"
            surface: "battery"
            shown: Battery.present
            implicitWidth: pct.implicitWidth
            implicitHeight: 17 * mods.s

            Text {
                id: pct
                anchors.centerIn: parent
                text: Battery.pct + "%"
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                font.family: Theme.font
                font.pixelSize: (mods.hover ? 13 : 14) * mods.s
                font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }

    readonly property Component musicbars: Component {
        MusicBars {
            readonly property bool shown: Flags.musicViz && Cava.active
            s: mods.s
        }
    }

    readonly property Component live: Component {
        LiveActivity {
            s: mods.s
            visible: mods.row.awake
            enabled: mods.row.live && mods.row.actions
        }
    }

    /**
     * Minimized windows plus the hairline that closes them off from the next module.
     */
    readonly property Component minimized: Component {
        Row {
            id: mini
            readonly property bool shown: parked.count > 0
            readonly property bool tail: parent ? parent.tail === true : false
            spacing: mods.row.clusterGap

            MinimizedTray {
                id: parked
                anchors.verticalCenter: parent.verticalCenter
                s: mods.s
                screenName: mods.row.screenName
                enabled: mods.row.live && mods.row.actions
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: !mini.tail
                width: 1
                height: (mods.hover ? 14 : 10) * mods.s
                color: Theme.hair
                opacity: 0.7
            }
        }
    }

    readonly property Component tray: Component {
        Tray {
            s: mods.s
            barWindow: mods.row.barWindow
            enabled: mods.row.live && mods.row.actions
        }
    }

    readonly property Component dnd: Component {
        Item {
            readonly property bool shown: Flags.dnd
            implicitWidth: 16 * mods.s
            implicitHeight: 16 * mods.s

            GlyphIcon {
                anchors.fill: parent
                name: "dnd"
                color: Theme.vermLit
                stroke: 1.7
            }
        }
    }

    readonly property Component wifi: Component {
        HoverIcon {
            row: mods.row
            iconId: "wifi"
            surface: "wifi"
            shown: Net.wifiDev !== null
            implicitWidth: 15 * mods.s
            implicitHeight: 15 * mods.s
            onRightClicked: Net.toggleWifi()

            WifiGlyph {
                anchors.centerIn: parent
                s: mods.s
                level: Net.wifiLevel
                on: Net.wifiOn
                stroke: 1.7
            }
        }
    }

    readonly property Component bt: Component {
        HoverIcon {
            id: btIcon

            readonly property bool lowShown: Peripherals.lowestPct >= 0 && Peripherals.lowestPct <= Peripherals.lowAt

            row: mods.row
            iconId: "bt"
            surface: "bt"
            shown: Net.btAdapter !== null
            implicitWidth: 15 * mods.s + (lowShown ? lowPct.implicitWidth + 4 * mods.s : 0)
            implicitHeight: 15 * mods.s
            onRightClicked: Net.toggleBt()

            GlyphIcon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * mods.s
                height: 15 * mods.s
                name: "bluetooth"
                color: btIcon.hovered ? Theme.cream
                    : (Peripherals.connectedCount > 0 ? Theme.vermLit
                    : (Net.btOn ? Theme.iconDim : Qt.alpha(Theme.iconDim, 0.4)))
                stroke: 1.7
            }

            Text {
                id: lowPct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: btIcon.lowShown
                text: Peripherals.lowestPct + "%"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 11 * mods.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    readonly property Component inbox: Component {
        HoverIcon {
            row: mods.row
            iconId: "inbox"
            surface: "link"
            glyph: "inbox"

            Rectangle {
                visible: Notifs.unread > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -2 * mods.s
                anchors.rightMargin: -2 * mods.s
                width: 5 * mods.s
                height: 5 * mods.s
                radius: width / 2
                color: Theme.flameGlow
            }
        }
    }

    readonly property Component mixer: Component {
        HoverIcon {
            row: mods.row
            iconId: "mixer"
            surface: "mixer"
            glyph: "mixer"
        }
    }

    readonly property Component sound: Component {
        HoverIcon {
            row: mods.row
            iconId: "sound"
            surface: "sound"
            glyph: "music"
            tint: Sound.eq ? Theme.vermLit : Theme.iconDim
        }
    }

    readonly property Component sysmon: Component {
        HoverIcon {
            row: mods.row
            iconId: "sysmon"
            surface: "sysmon"
            glyph: "monitor"
        }
    }

    readonly property Component recorder: Component {
        HoverIcon {
            row: mods.row
            iconId: "recorder"
            surface: "recorder"
            glyph: ScreenRec.recording ? "" : "video"
            onRightClicked: if (ScreenRec.recording) ScreenRec.stop()
            onDoubleClicked: if (ScreenRec.recording) ScreenRec.stop()

            Rectangle {
                anchors.centerIn: parent
                visible: ScreenRec.recording
                width: 12 * mods.s
                height: 12 * mods.s
                radius: width / 2
                color: Theme.verm
                SequentialAnimation on opacity {
                    running: ScreenRec.recording && mods.row.live && !Motion.calm
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    readonly property Component settings: Component {
        HoverIcon {
            row: mods.row
            iconId: "settings"
            surface: "settings"
            glyph: "cog"
            stroke: 1.6
        }
    }

    readonly property Component power: Component {
        HoverIcon {
            row: mods.row
            iconId: "power"
            surface: "power"
            glyph: "shutdown"
        }
    }
}
