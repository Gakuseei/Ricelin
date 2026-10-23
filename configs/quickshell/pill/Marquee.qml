import QtQuick
import Qt5Compat.GraphicalEffects
import "Singletons"

/**
 * One line that ends in an ellipsis at rest and scrolls on hover; it snaps to whole pixels so native text stays crisp.
 */
Item {
    id: root

    property string text: ""
    property color color: Theme.cream
    property real pixelSize: 14
    property int weight: Font.Normal
    property bool active: true
    property real s: 1

    property real scrollX: 0

    implicitHeight: label.implicitHeight
    clip: true

    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    readonly property bool scrolling: active && hover.hovered && overflow > 0 && !Motion.calm
    readonly property bool unrolled: scrolling || scrollX < 0
    readonly property real edge: 16 * s

    HoverHandler {
        id: hover
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        visible: !root.unrolled
        text: root.text
        color: root.color
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        font: label.font
    }

    /**
     * A second, never-elided copy scrolls: Text keeps a stale elided layout when elide is switched off.
     */
    Item {
        id: viewport
        anchors.fill: parent
        visible: root.unrolled

        layer.enabled: root.unrolled
        layer.effect: OpacityMask {
            maskSource: fade
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(root.scrollX)
            text: root.text
            color: root.color
            renderType: Text.NativeRendering
            font.family: Theme.font
            font.pixelSize: root.pixelSize
            font.weight: root.weight
        }
    }

    /**
     * Each edge softens only while text actually runs past it.
     */
    Rectangle {
        id: fade
        anchors.fill: parent
        visible: false
        readonly property real lead: Math.min(root.edge, -root.scrollX) / Math.max(1, width)
        readonly property real tail: Math.min(root.edge, root.overflow + root.scrollX) / Math.max(1, width)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: fade.lead > 0 ? "transparent" : "white" }
            GradientStop { position: fade.lead; color: "white" }
            GradientStop { position: 1 - fade.tail; color: "white" }
            GradientStop { position: 1; color: fade.tail > 0 ? "transparent" : "white" }
        }
    }

    SequentialAnimation {
        id: run
        loops: Animation.Infinite
        PauseAnimation { duration: Motion.standard }
        NumberAnimation {
            target: root
            property: "scrollX"
            to: -root.overflow
            duration: Math.max(1, root.overflow) * 22
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: Motion.heat }
        NumberAnimation {
            target: root
            property: "scrollX"
            to: 0
            duration: Math.max(1, root.overflow) * 22
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: Motion.heat }
    }

    NumberAnimation {
        id: home
        target: root
        property: "scrollX"
        to: 0
        duration: Motion.glide
        easing.type: Easing.OutCubic
    }

    onScrollingChanged: sync()
    onTextChanged: {
        run.stop();
        home.stop();
        scrollX = 0;
        sync();
    }

    /**
     * Imperative on purpose: a `running` binding is severed by the first stop() and would loop on inside a hidden surface.
     */
    function sync() {
        if (scrolling) {
            home.stop();
            run.restart();
        } else {
            run.stop();
            if (scrollX < 0)
                home.restart();
        }
    }
}
