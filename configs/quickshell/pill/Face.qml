import QtQuick
import "Singletons"

/**
 * One of the pill's own faces: it enters as the shape arrives in `mode` and leaves on a short timed fade.
 */
Item {
    id: face

    required property Item host
    property string mode
    property int exitMs: 110
    property bool when: true
    readonly property bool live: when && host.mode === mode
    readonly property real enter: Motion.reveal(host.morphCloseness)

    property real exitFade: 0
    property real lastShown: 0

    anchors.fill: parent
    enabled: live
    opacity: live ? enter : exitFade
    visible: live || opacity > 0.01

    onOpacityChanged: if (live) lastShown = opacity
    onLiveChanged: {
        if (live) {
            fadeOut.stop();
        } else {
            exitFade = lastShown;
            fadeOut.restart();
        }
    }

    NumberAnimation {
        id: fadeOut
        target: face
        property: "exitFade"
        to: 0
        duration: face.exitMs
        easing.type: Easing.OutCubic
    }
}
