import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property int saved: 0
    property int expected: Quickshell.screens.length

    function maybeQuit() {
        if (root.saved >= root.expected) {
            console.log("rishot-spike: all " + root.saved + " captures saved, quitting");
            Qt.quit();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background

            ScreencopyView {
                id: view
                anchors.fill: parent
                captureSource: win.modelData
                live: false
                paintCursor: false

                property bool grabbed: false

                onHasContentChanged: grabTimer.start()
                Component.onCompleted: captureFrame()

                Timer {
                    id: grabTimer
                    interval: 50
                    repeat: false
                    onTriggered: view.tryGrab()
                }

                function tryGrab() {
                    if (grabbed || !hasContent) return;
                    if (sourceSize.width <= 0 || sourceSize.height <= 0) return;
                    grabbed = true;
                    var path = "/tmp/rishot-spike-" + win.modelData.name + ".png";
                    console.log("rishot-spike: grabbing " + win.modelData.name
                        + " " + sourceSize.width + "x" + sourceSize.height);
                    var ok = view.grabToImage(function(result) {
                        var w = result.saveToFile(path);
                        console.log("rishot-spike: saveToFile " + path + " => " + w);
                        root.saved += 1;
                        root.maybeQuit();
                    });
                    console.log("rishot-spike: grabToImage requested => " + ok);
                }
            }
        }
    }

    Timer {
        interval: 8000
        running: true
        repeat: false
        onTriggered: {
            console.log("rishot-spike: timeout, saved=" + root.saved);
            Qt.quit();
        }
    }
}
