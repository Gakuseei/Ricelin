pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * The blade fan: a quarter-circle of guide rays and arcs growing out of the
 * top-left corner, with one capsule "blade" per game or Wine app laid along its
 * own ray like a spread hand of cards.
 *
 *        blade
 *          ───────────
 *        /
 *       /
 *      ◉────────────── blade
 *       \
 *        \
 *          ───────────
 *
 * This item only draws and reports clicks. When it opens, and where the pointer
 * is, is decided by the BladeLayer window around it; the apps come from a
 * BladeLauncherModel (anything with count, appAt, stateFor, labelFor and
 * launch(index) works, which is also how the offscreen preview drives it).
 */
Item {
    id: fan

    required property var model

    /** Overall scale, the same screen-height factor the pill uses. */
    property real s: 1
    /** Whether the fan should be open. The spread itself animates in `progress`. */
    property bool open: false

    signal toggleRequested()
    signal launched()

    readonly property real originX: 24 * s
    readonly property real originY: 24 * s
    readonly property real beadSize: 44 * s
    readonly property real sectorSize: 540 * s
    readonly property real fanStartRadius: 250 * s
    readonly property real fanEndRadius: 505 * s
    readonly property real bladeHeight: 52 * s
    /** How far from the origin the pointer still counts as "on the fan". */
    readonly property real reach: sectorSize + 30 * s
    /** Size of the square the fan needs: origin offset plus its reach. */
    readonly property real extent: originX + reach

    readonly property int count: model ? model.count : 0

    property real progress: open ? 1 : 0
    Behavior on progress {
        NumberAnimation {
            duration: Motion.morph
            easing.type: Motion.easeMorph
            easing.bezierCurve: Motion.morphCurve
        }
    }

    function fanAngle(index) {
        return count <= 1 ? 43 : 8 + 70 * index / (count - 1);
    }

    /** Per-blade progress: later blades start slightly after earlier ones, so the fan unfolds instead of popping. */
    function bladeProgress(index) {
        var lag = count > 1 ? 0.08 : 0;
        return Math.max(0, Math.min(1, (progress - lag * index) / (1 - lag * (count - 1))));
    }

    // Soft glass sector the fan sits on.
    Shape {
        visible: fan.progress > 0.002
        opacity: fan.progress
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Theme.bright, 0.16)
            strokeWidth: 1
            fillGradient: RadialGradient {
                centerX: fan.originX
                centerY: fan.originY
                centerRadius: fan.sectorSize
                focalX: fan.originX
                focalY: fan.originY
                GradientStop { position: 0; color: Qt.alpha(Theme.cardTop, 0.62) }
                GradientStop { position: 1; color: Qt.alpha(Theme.cardBot, 0.10) }
            }
            startX: fan.originX
            startY: fan.originY
            PathLine { x: fan.originX + fan.sectorSize; y: fan.originY }
            PathArc {
                x: fan.originX
                y: fan.originY + fan.sectorSize
                radiusX: fan.sectorSize
                radiusY: fan.sectorSize
                direction: PathArc.Clockwise
            }
            PathLine { x: fan.originX; y: fan.originY }
        }
    }

    // Concentric guide arcs.
    Repeater {
        model: [150, 250, 350, 450, 520]

        delegate: Shape {
            id: arc
            required property real modelData
            readonly property real r: modelData * fan.s

            x: fan.originX - r
            y: fan.originY - r
            width: r * 2
            height: r * 2
            visible: fan.progress > 0.002
            opacity: 0.55 * fan.progress
            antialiasing: true

            ShapePath {
                strokeColor: Qt.alpha(Theme.cream, 0.20)
                strokeWidth: 1
                fillColor: "transparent"
                PathAngleArc {
                    centerX: arc.r
                    centerY: arc.r
                    radiusX: arc.r
                    radiusY: arc.r
                    startAngle: 0
                    sweepAngle: 90
                }
            }
        }
    }

    // Guide rays, one per blade.
    Repeater {
        model: fan.count

        delegate: Rectangle {
            id: ray
            required property int index

            x: fan.originX
            y: fan.originY - 0.5
            width: fan.fanEndRadius
            height: 1
            transformOrigin: Item.Left
            rotation: fan.fanAngle(0) + (fan.fanAngle(index) - fan.fanAngle(0)) * fan.bladeProgress(index)
            visible: fan.progress > 0.002
            opacity: 0.30 * fan.progress
            color: Theme.cream
        }
    }

    // Origin bead: the handle. Clicking it pins the fan open.
    Glass {
        id: bead
        x: fan.originX - width / 2
        y: fan.originY - height / 2
        width: fan.beadSize
        height: width
        radius: width / 2
        clarity: fan.open ? 0.42 : 0.5
        lit: fan.open

        GlyphIcon {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: width
            name: "gamepad"
            color: fan.open ? Theme.bright : Theme.iconDim
            stroke: 1.7
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: fan.toggleRequested()
        }
    }

    // The blades.
    Repeater {
        model: fan.count

        delegate: Item {
            id: blade
            required property int index

            readonly property var app: fan.model.appAt(index)
            readonly property string appState: fan.model.stateFor(index)
            readonly property real p: fan.bladeProgress(index)

            // Angle of this blade right now: it starts lying along the first ray and
            // swings out to its own as the fan opens, pivoting about the origin.
            readonly property real theta: fan.fanAngle(0) + (fan.fanAngle(index) - fan.fanAngle(0)) * p

            width: fan.fanEndRadius - fan.fanStartRadius
            height: fan.bladeHeight
            x: fan.originX + Math.cos(theta * Math.PI / 180) * fan.fanStartRadius
            y: fan.originY + Math.sin(theta * Math.PI / 180) * fan.fanStartRadius - height / 2
            z: 100 + index
            visible: p > 0.002
            opacity: p
            rotation: theta
            transformOrigin: Item.Left

            property real grow: tap.pressed ? 0.985 : (hover.hovered ? 1.04 : 1)
            Behavior on grow { SpringAnimation { spring: 4; damping: 0.32 } }
            scale: grow

            Glass {
                anchors.fill: parent
                radius: height / 2
                clarity: hover.hovered ? 0.34 : 0.52
                lit: hover.hovered

                Rectangle {
                    id: tile
                    anchors.left: parent.left
                    anchors.leftMargin: 9 * fan.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height - 18 * fan.s
                    height: width
                    radius: width / 2
                    color: Qt.alpha(Theme.tileBg, 0.85)
                    border.width: 1
                    border.color: Theme.hair

                    Text {
                        anchors.centerIn: parent
                        visible: !icon.visible
                        text: blade.app && blade.app.name.length > 0 ? blade.app.name.charAt(0).toUpperCase() : "?"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 15 * fan.s
                        font.weight: Font.DemiBold
                    }

                    Image {
                        id: icon
                        anchors.fill: parent
                        anchors.margins: 6 * fan.s
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready && source != ""
                        source: blade.app && blade.app.iconImage && blade.app.iconImage.length > 0 ? "file://" + blade.app.iconImage : ""
                    }
                }

                Column {
                    anchors.left: tile.right
                    anchors.leftMargin: 11 * fan.s
                    anchors.right: dot.left
                    anchors.rightMargin: 8 * fan.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * fan.s

                    Text {
                        width: parent.width
                        text: blade.app ? blade.app.name : ""
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * fan.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: {
                            var base = fan.model.labelFor(blade.index);
                            if (blade.appState === "running")
                                return base + "  ·  running";
                            if (blade.appState === "launching")
                                return base + "  ·  starting";
                            return base;
                        }
                        color: blade.appState === "idle" ? Theme.faint : Theme.flameGlow
                        font.family: Theme.font
                        font.pixelSize: 10 * fan.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: dot
                    anchors.right: parent.right
                    anchors.rightMargin: 16 * fan.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8 * fan.s
                    height: width
                    radius: width / 2
                    visible: blade.appState !== "idle"
                    color: Theme.onGlow
                    SequentialAnimation on opacity {
                        running: dot.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: Motion.pulse; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                    }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tap
                onTapped: {
                    fan.model.launch(blade.index);
                    fan.launched();
                }
            }
        }
    }
}
