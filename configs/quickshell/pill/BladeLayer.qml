pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "Singletons" as S

/*
 * Ricelin corner application launcher.
 *
 * The visual language is a quarter-circle sector:
 *
 *        blade
 *          ─────────
 *        /
 *       /
 *      ●──────────── blade
 *       \
 *        \
 *          ─────────
 *
 * The origin is the physical top-left corner. Guide rays and concentric
 * arcs establish the sector, while application blades branch between them.
 *
 * This layer is independent from Pill.qml.
 */
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: true
    color: "transparent"

    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ricelin-blades"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    /*
     * This is deliberately the same small input envelope as the visual
     * launcher. The rest of the fullscreen layer remains click-through.
     */
    mask: Region {
       x: state.expanded
           ? state.originX - (state.sectorSize + 30)
           : state.originX - 21

       y: state.expanded
           ? state.originY - (state.sectorSize + 30)
           : state.originY - 21

       width: state.expanded
           ? (state.sectorSize + 30) * 2
           : 42

       height: state.expanded
           ? (state.sectorSize + 30) * 2
           : 42

       shape: RegionShape.Ellipse
   }

    BladeLauncherModel {
        id: bladeModel
    }

    QtObject {
        id: state

        property bool expanded: false

        readonly property real originX: 24
        readonly property real originY: 24

        readonly property real sectorSize: 540

        readonly property real rayLength: 500

        readonly property int visibleCount:
            Math.min(bladeModel.count, bladeModel.maxVisible)

        /*
         * Keep the quarter-circle fan concept, but start the actual
         * capsules farther away from the origin so they do not stack.
         */
        readonly property real fanStartRadius: 235
        readonly property real fanEndRadius: 505

        function fanAngle(index) {
            var n = state.visibleCount

            if (n <= 1)
                return 43

            return 8 + (78 - 8) * index / (n - 1)
        }

        function fanStartX(index) {
            var a = fanAngle(index) * Math.PI / 180
            return originX + Math.cos(a) * fanStartRadius
        }

        function fanStartY(index) {
            var a = fanAngle(index) * Math.PI / 180
            return originY + Math.sin(a) * fanStartRadius
        }

        function fanBladeLength() {
            return fanEndRadius - fanStartRadius
        }
    }

    /*
     * Very light translucent backing. This is not the blur yet.
     * It gives the sector something to sit on without obscuring the desktop.
     */
    Rectangle {
        visible: state.expanded

        x: 0
        y: 0

        width: state.sectorSize + 30
        height: state.sectorSize + 30

        color: Qt.alpha("white", 0.055)

        border.width: 1
        border.color: Qt.alpha("white", 0.10)

        radius: 24

        opacity: state.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: S.Motion.morph
                easing.type: S.Motion.easeMorph
                easing.bezierCurve: S.Motion.morphCurve
            }
        }
    }

    /*
     * Guide rays.
     */
    Repeater {
        model: state.visibleCount

        delegate: Rectangle {
            required property real modelData

            x: state.originX
            y: state.originY - 0.5

            width: state.rayLength
            height: 1

            transformOrigin: Item.Left
            rotation: state.fanAngle(modelData)

            visible: state.expanded
            opacity: 0.20

            color: "white"

            Behavior on opacity {
                NumberAnimation {
                    duration: S.Motion.morph
                }
            }
        }
    }

    /*
     * Concentric circular guide lines.
     *
     * The circles are intentionally incomplete visually because only their
     * upper-right quarter is relevant to the launcher.
     */
    Repeater {
        model: [150, 250, 350, 450, 520]

        delegate: Shape {
            required property real modelData

            x: state.originX - modelData
            y: state.originY - modelData

            width: modelData * 2
            height: modelData * 2

            visible: state.expanded
            opacity: 0.15

            antialiasing: true

            ShapePath {
                strokeColor: "white"
                strokeWidth: 1
                fillColor: "transparent"

                PathAngleArc {
                    centerX: modelData
                    centerY: modelData
                    radiusX: modelData
                    radiusY: modelData
                    startAngle: 0
                    sweepAngle: 90
                }
            }
        }
    }

    /*
     * Origin bead.
     */
    Rectangle {
        id: origin

        x: state.originX - width / 2
        y: state.originY - height / 2

        width: state.expanded ? 42 : 38
        height: width

        radius: width / 2

        color: Qt.alpha("white", state.expanded ? 0.24 : 0.17)

        border.width: 1
        border.color: Qt.alpha("white", 0.42)

        Behavior on width {
            SpringAnimation {
                spring: 3.5
                damping: 0.35
            }
        }

        Behavior on height {
            SpringAnimation {
                spring: 3.5
                damping: 0.35
            }
        }

        Text {
            anchors.centerIn: parent

            text: "✦"

            color: Qt.alpha("white", 0.92)

            font.pixelSize: state.expanded ? 18 : 17
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: state.expanded = !state.expanded
        }
    }

    /*
     * Application blades.
     *
     * Each blade is placed on its own branch angle and radius rather than
     * simply following a single ray. This creates the fan/protractor effect.
     */
    Repeater {
        model: state.visibleCount

        delegate: Item {
            id: bladeItem

            required property int index

            property real targetAngle:
               state.fanAngle(index)

property real branchLength:
                state.fanBladeLength()

            property real hoverScale:
                hover.hovered ? 1.045 : 1.0

            width: branchLength
            height: 56
            z: 100 + bladeItem.index
            visible: state.expanded
            opacity: state.expanded ? 1 : 0

           /*
            * Shared pivot: the cards behave like a spread deck
            * held from one corner rather than separate spokes.
            */
           x: state.fanStartX(index)
           y: state.fanStartY(index) - bladeItem.height / 2

            transformOrigin: Item.Left

            rotation: targetAngle

            transform: Scale {
                origin.x: 0
                origin.y: bladeItem.height / 2

                xScale: bladeItem.hoverScale
                yScale: bladeItem.hoverScale
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: S.Motion.fast
                }
            }

            Behavior on hoverScale {
                SpringAnimation {
                    spring: 4.0
                    damping: 0.32
                }
            }

            /*
             * The actual blade is a rounded translucent capsule.
             */
            Rectangle {
                id: blade

                anchors.fill: parent

                radius: height / 2

                color: hover.hovered
                    ? Qt.alpha("white", 0.78)
                    : Qt.alpha("white", 0.47)

                border.width: hover.hovered ? 2 : 1
                border.color: hover.hovered
                    ? Qt.alpha("white", 0.90)
                    : Qt.alpha("white", 0.32)

                RowLayout {
                    anchors.fill: parent

                    anchors.leftMargin: 14
                    anchors.rightMargin: 13

                    spacing: 8

                    /*
                     * Small branch marker.
                     */
                    Text {
                        text: "◆"

                        color: Qt.alpha("black", 0.42)

                        font.pixelSize: 7
                    }

                    Text {
                        Layout.fillWidth: true

                        text: bladeModel.appAt(bladeItem.index)?.name ?? ""

                        color: Qt.alpha("black", 0.88)

                        font.family: S.Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold

                        elide: Text.ElideRight
                    }

                    Text {
                       text: bladeModel.isLaunching(bladeItem.index)
                           ? "◌"
                           : S.AppLauncher.isRunning(
                                 bladeModel.appAt(bladeItem.index)?.id ?? ""
                             )
                               ? "●"
                               : ""

                       color: Qt.alpha("black", 0.46)

                       font.pixelSize: 7
                   }
                }
            }

            

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent

                cursorShape: Qt.PointingHandCursor

                onPressed: {
                    console.warn(
                        "BladeLayer DEBUG PRESSED index=",
                        bladeItem.index,
                        "name=",
                        bladeModel.appAt(bladeItem.index)?.name ?? "(null)"
                    )
                }

                onClicked: {
                    console.warn(
                        "BladeLayer DEBUG CLICKED index=",
                        bladeItem.index
                    )

                    bladeModel.launch(bladeItem.index)
                    state.expanded = false
                }
            }
        }
    }
}
