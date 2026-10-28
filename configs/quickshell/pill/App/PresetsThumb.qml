import QtQuick
import QtQuick.Effects
import ".."
import "../Singletons"

/** A resting pill drawn from a preset's values instead of the live flags: its shape, surface and idle modules. */
Item {
    id: thumb

    property var values: ({})
    property real s: 1

    readonly property real baseH: Math.max(24, Math.min(64, Number(values.pillHeight) || 38))
    readonly property real corner: Math.max(0, Math.min(Number(values.pillRounding), baseH / 2)) * s
    readonly property real fillAlpha: values.pillOpacity === undefined ? 1 : Number(values.pillOpacity)

    implicitWidth: Math.max((Number(values.idleWidth) || 160) * s, row.implicitWidth + 36 * s)
    implicitHeight: baseH * s

    RectangularShadow {
        anchors.fill: body
        visible: thumb.values.pillShadow !== false
        radius: body.radius
        blur: 22 * thumb.s
        offset.y: 3 * thumb.s
        color: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: thumb.corner
        border.width: thumb.values.pillBorder === false ? 0 : 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, thumb.fillAlpha) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, thumb.fillAlpha) }
        }

        Rectangle {
            visible: thumb.values.pillSheen !== false
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

    ModuleRow {
        id: row
        anchors.centerIn: parent
        ids: thumb.values.idleModules || []
        glyphsOn: thumb.values.showGlyphs !== false
        glyphText: thumb.values.restGlyph || ""
        phase: "rest"
        s: thumb.s
        live: false
        actions: false
    }
}
