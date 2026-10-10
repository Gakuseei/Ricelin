import QtQuick
import QtMultimedia
import "Singletons"

Item {
    id: root

    property bool active: false
    property var captureSession: null

    width: 640
    height: 360

    visible: active
    enabled: false

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: "black"
        clip: true

        VideoOutput {
            id: videoOutput

            anchors.fill: parent

            fillMode:
                VideoOutput.PreserveAspectCrop

            mirrored: CameraRec.mirrored
        }
    }

    Binding {
        target: root.captureSession

        property: "videoOutput"

        value: videoOutput

        when:
            root.active &&
            root.captureSession !== null
    }

    Rectangle {
        anchors.fill: parent

        radius: 16

        color: "transparent"

        border.width: 2

        border.color:
            Qt.rgba(1, 1, 1, 0.78)
    }

    /*
     * Small recording marker inside the PiP.
     */
    Row {
        anchors.left: parent.left
        anchors.top: parent.top

        anchors.leftMargin: 12
        anchors.topMargin: 10

        spacing: 6

        Rectangle {
            width: 7
            height: 7

            radius: 3.5

            color: "#ff4354"

            SequentialAnimation on opacity {
                running: root.active
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.25
                    duration: 500
                }

                NumberAnimation {
                    to: 1
                    duration: 500
                }
            }
        }

        Text {
            text: "CAM"

            color: "white"

            font.pixelSize: 9
            font.weight: Font.ExtraBold
            font.letterSpacing: 1.1
        }
    }
}
