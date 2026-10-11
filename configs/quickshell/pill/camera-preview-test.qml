import QtQuick
import QtMultimedia
import Quickshell
import "Singletons"

FloatingWindow {
    id: win

    title: "Camera Preview"

    width: 640
    height: 360

    minimumSize: Qt.size(320, 180)
    maximumSize: Qt.size(1280, 720)

    Component.onCompleted: {
        CameraRec.startCamera()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        clip: true

        VideoOutput {
            id: videoOutput

            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            mirrored: true
        }
    }

    Binding {
        target: CameraRec.captureSession
        property: "videoOutput"
        value: videoOutput
    }

    Component.onDestruction: {
        CameraRec.stopCamera()
    }
}
