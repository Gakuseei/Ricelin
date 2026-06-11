pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import "Singletons"

/**
 * The washi pill body — a single element that carries every state. Its width and
 * height are driven by `state` (rest, hover/pinned, mixer, calendar) and settled
 * with a critically-damped, no-overshoot easing, so each surface grows out of the
 * pill in place rather than appearing as a separate window. The four surfaces are
 * absolutely stacked and cross-fade, exactly as the approved prototype does.
 *
 * Hover is read by a passive HoverHandler and pin by a passive TapHandler, so
 * neither blocks pointer events from the interactive surfaces stacked above them:
 * workspace dots, the clock target, tray icons and the mixer faders all receive
 * their own clicks and drags directly.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    readonly property bool held: pinned || forcePinned
    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool powerOpen: surface === "power"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool hasMedia: Mpris.players.values.length > 0
    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false
    readonly property bool expanded: surfaceOpen || held || hoverLatch
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    readonly property real restW: 160 * s
    readonly property real restH: 38 * s
    readonly property real hoverPad: 20 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 58 * s
    readonly property real mixerW: 372 * s
    readonly property real mixerH: 206 * s
    readonly property real calendarW: 318 * s
    readonly property real calendarH: calendar.implicitHeight + 32 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real powerW: 330 * s
    readonly property real powerH: 150 * s
    readonly property real mediaW: 336 * s
    readonly property real mediaH: 122 * s
    readonly property real toastW: 342 * s
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    readonly property string mode: calendarOpen ? "calendar"
        : (launcherOpen ? "launcher"
        : (powerOpen ? "power"
        : (mediaOpen ? "media"
        : (mixerOpen ? "mixer"
        : (linkOpen ? "link"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest"))))))))

    signal requestSurface(string name)
    signal requestClose()

    /**
     * Forward an arrow-key nudge to the open mixer's targeted fader. Returns true
     * when the mixer is open and a fader consumed the step.
     */
    function mixerStep(deltaPct) {
        return pill.mixerOpen ? mixer.stepFocused(deltaPct) : false;
    }

    /**
     * Move the open mixer's keyboard focus across the fader row; `dir` is +1
     * (right) or -1 (left). No-op unless the mixer is open.
     */
    function mixerFocusMove(dir) {
        if (pill.mixerOpen)
            mixer.moveFocus(dir);
    }

    /**
     * Pop the open link surface one subview back. Returns true when the step was
     * consumed, false when the surface is already at its root (or not open) and
     * Escape should close the surface instead.
     */
    function linkBack() {
        return pill.linkOpen ? link.back() : false;
    }

    onSurfaceOpenChanged: if (surfaceOpen) pinned = false

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, "HH:mm")
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property real morphRadius: (mixerOpen || calendarOpen || launcherOpen || powerOpen || mediaOpen || linkOpen || mode === "toast" || mode === "osd") ? openCorner : restCorner

    width: mode === "calendar" ? calendarW
        : mode === "launcher" ? launcherW
        : mode === "power" ? powerW
        : mode === "media" ? mediaW
        : mode === "mixer" ? mixerW
        : mode === "link" ? link.desiredW
        : mode === "osd" ? osd.desiredW
        : mode === "toast" ? toastW
        : mode === "hover" ? hoverW
        : Math.max(restW, restRow.implicitWidth + 36 * s)
    height: mode === "calendar" ? calendarH
        : mode === "launcher" ? launcherH
        : mode === "power" ? powerH
        : mode === "media" ? mediaH
        : mode === "mixer" ? mixerH
        : mode === "link" ? link.implicitHeight + 26 * s
        : mode === "osd" ? osd.desiredH
        : mode === "toast" ? (toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH)
        : mode === "hover" ? hoverH : restH

    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph } }
    Behavior on morphRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph } }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: pill.morphRadius
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * pill.s
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: body.radius * 0.6
            anchors.rightMargin: body.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        pillW: pill.width
        pillH: pill.height
        heat: pill.powerOpen ? power.holdProgress : 0
        form: pill.mediaOpen ? "seam"
            : (pill.launcherOpen ? "caret"
            : (pill.calendarOpen ? (calendar.todayVisible ? "ring" : "dock")
            : (pill.mixerOpen || pill.powerOpen || pill.linkOpen ? "dock"
            : (pill.mode === "toast" || pill.mode === "osd" ? "off"
            : "rest"))))
        point: pill.mediaOpen
            ? Qt.point(media.x + media.seamHeadX, media.y + media.seamHeadY)
            : (pill.launcherOpen
            ? Qt.point(launcher.x + launcher.caretX, launcher.y + launcher.caretY)
            : (pill.calendarOpen
            ? (calendar.todayVisible
                ? Qt.point(calendar.x + calendar.todayX, calendar.y + calendar.todayY)
                : Qt.point(pill.width / 2, pill.height / 2))
            : (pill.mixerOpen
            ? Qt.point(mixer.x + mixer.focusTickPoint.x, mixer.y + mixer.focusTickPoint.y)
            : (pill.powerOpen
            ? Qt.point(power.x + power.heatX, power.y + power.heatY)
            : (pill.linkOpen
            ? Qt.point(link.x + link.emberX, link.y + link.emberY)
            : Qt.point(pill.width - 14 * pill.s, pill.height / 2))))))
    }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: pill.hovered = hovered
    }

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
        } else {
            graceTimer.restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 250
        onTriggered: pill.hoverLatch = false
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (pill.expanded || pill.mode === "toast" || pill.mode === "osd") ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            id: restRow
            anchors.centerIn: parent
            spacing: 9 * pill.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "時"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 15 * pill.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        opacity: pill.mode === "hover" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        readonly property bool live: pill.mode === "hover"

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 20 * pill.s

            Workspaces {
                id: ws
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                screenName: pill.screenName
                s: pill.s
                gap: 8 * pill.s
                enabled: hover.live
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: hoverClock.implicitWidth
                height: hoverClock.implicitHeight

                Column {
                    id: hoverClock
                    anchors.centerIn: parent
                    spacing: 2 * pill.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * pill.s
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * pill.s

                MinimizedTray {
                    id: minimized
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    screenName: pill.screenName
                    enabled: hover.live
                    visible: count > 0
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: minimized.count > 0
                    width: 1
                    height: 14 * pill.s
                    color: Theme.hair
                    opacity: 0.7
                }

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                Shape {
                    id: dndIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.dnd
                    width: 16 * pill.s
                    height: 16 * pill.s
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 5.2 * pill.s; startY: 12.2 * pill.s
                        PathLine { x: 12.2 * pill.s; y: 12.2 * pill.s }
                        PathLine { x: 12.2 * pill.s; y: 7.2 * pill.s }
                        PathCubic {
                            control1X: 12.2 * pill.s; control1Y: 5.4 * pill.s
                            control2X: 11.2 * pill.s; control2Y: 4.0 * pill.s
                            x: 9.5 * pill.s; y: 3.5 * pill.s
                        }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 6.8 * pill.s; startY: 13.6 * pill.s
                        PathLine { x: 9.2 * pill.s; y: 13.6 * pill.s }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.6 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 3.2 * pill.s; startY: 2.8 * pill.s
                        PathLine { x: 13.0 * pill.s; y: 13.4 * pill.s }
                    }
                }

                Item {
                    id: inboxIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "inbox"
                        color: inboxArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        visible: Notifs.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2 * pill.s
                        anchors.rightMargin: -2 * pill.s
                        width: 5 * pill.s
                        height: 5 * pill.s
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: inboxArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("link")
                    }
                }

                Item {
                    id: mixerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "mixer"
                        color: mixerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: mixerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("mixer")
                    }
                }

                Item {
                    id: powerIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "shutdown"
                        color: powerArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("power")
                    }
                }
            }
        }
    }

    Mixer {
        id: mixer
        anchors.fill: parent
        anchors.topMargin: 13 * pill.s
        anchors.leftMargin: 14 * pill.s
        anchors.rightMargin: 14 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s
        active: pill.mixerOpen
        enabled: pill.mixerOpen
        opacity: pill.mixerOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    Calendar {
        id: calendar
        anchors.fill: parent
        anchors.topMargin: 16 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 16 * pill.s
        s: pill.s
        active: pill.calendarOpen
        enabled: pill.calendarOpen
        opacity: pill.calendarOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }
    }

    Launcher {
        id: launcher
        anchors.fill: parent
        anchors.topMargin: 15 * pill.s
        anchors.leftMargin: 17 * pill.s
        anchors.rightMargin: 17 * pill.s
        anchors.bottomMargin: 14 * pill.s
        s: pill.s
        active: pill.launcherOpen
        enabled: pill.launcherOpen
        opacity: pill.launcherOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onRequestClose: pill.requestClose()
    }

    Power {
        id: power
        anchors.fill: parent
        anchors.topMargin: 15 * pill.s
        anchors.leftMargin: 17 * pill.s
        anchors.rightMargin: 17 * pill.s
        anchors.bottomMargin: 14 * pill.s
        s: pill.s
        active: pill.powerOpen
        enabled: pill.powerOpen
        opacity: pill.powerOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onRequestClose: pill.requestClose()
    }

    Media {
        id: media
        anchors.fill: parent
        anchors.margins: 15 * pill.s
        s: pill.s
        active: pill.mediaOpen
        enabled: pill.mediaOpen
        opacity: pill.mediaOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onRequestClose: pill.requestClose()
    }

    Link {
        id: link
        anchors.fill: parent
        anchors.topMargin: 13 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 13 * pill.s
        s: pill.s
        active: pill.linkOpen
        enabled: pill.linkOpen
        opacity: pill.linkOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s
        suppressed: pill.surfaceOpen || pill.held
        enabled: pill.mode === "osd"
        opacity: pill.mode === "osd" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 12 * pill.s
        enabled: pill.mode === "toast"
        opacity: pill.mode === "toast" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: pill.s
                live: pill.mode === "toast"
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
                onOpenCenter: pill.requestSurface("link")
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Notifs.popups.length > 1
                text: "+" + (Notifs.popups.length - 1)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * pill.s
                font.weight: Font.DemiBold
            }
        }
    }

    MouseArea {
        visible: ame.form === "rest" && pill.hasMedia
        x: ame.bx - 16 * pill.s
        y: ame.by - 16 * pill.s
        width: 32 * pill.s
        height: 32 * pill.s
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.requestSurface("media")
    }
}
