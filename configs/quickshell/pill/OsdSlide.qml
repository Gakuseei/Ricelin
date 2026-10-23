import QtQuick
import "Singletons"

/**
 * One OSD row: it leaves fast and enters after a delay, so a swap never shows two rows at half strength.
 */
Item {
    id: slide

    property string k
    property bool current: false
    property int leaveMs: 100
    property int delay: 0
    signal entering()

    anchors.fill: parent
    opacity: current ? 1 : 0
    visible: opacity > 0.01

    /**
     * A negative delay snaps in: a fresh flash is already revealed by the pill's own face.
     */
    function show(ms) {
        outAnim.stop();
        inAnim.stop();
        if (ms < 0) {
            opacity = 1;
            entering();
            return;
        }
        opacity = 0;
        delay = ms;
        inAnim.start();
    }

    function hide(fade) {
        inAnim.stop();
        if (fade && opacity > 0.01) {
            outAnim.restart();
        } else {
            outAnim.stop();
            opacity = 0;
        }
    }

    SequentialAnimation {
        id: inAnim
        PauseAnimation { duration: slide.delay }
        ScriptAction { script: slide.entering() }
        NumberAnimation { target: slide; property: "opacity"; to: 1; duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: outAnim
        target: slide
        property: "opacity"
        to: 0
        duration: slide.leaveMs
        easing.type: Easing.OutCubic
    }
}
