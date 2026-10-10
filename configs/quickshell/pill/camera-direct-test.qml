import QtQuick
import QtMultimedia
import Quickshell

FloatingWindow {
    id: win

    title: "Direct Camera Test"

    implicitWidth: 640
    implicitHeight: 480

    MediaDevices {
        id: devices
    }

    Camera {
        id: camera
        cameraDevice: devices.defaultVideoInput
        active: true

        onErrorOccurred: function(error, errorString) {
            console.error("DIRECT CAMERA ERROR:", errorString)
        }

        onActiveChanged: {
            if (active) {
                Qt.callLater(function() {
                    console.log(
                        "DIRECT:",
                        "exposureMode=", camera.exposureMode,
                        "exposureTime=", camera.exposureTime,
                        "manualExposureTime=", camera.manualExposureTime,
                        "iso=", camera.isoSensitivity,
                        "manualISO=", camera.manualIsoSensitivity
                    )
                })
            }
        }
    }

    CaptureSession {
        id: session
        camera: camera
    }

    Rectangle {
        anchors.fill: parent
        color: "black"

        VideoOutput {
            id: output
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            mirrored: true
        }
    }

    Binding {
        target: session
        property: "videoOutput"
        value: output
    }

    Component.onCompleted: {
        console.log("DIRECT CAMERA:", devices.defaultVideoInput.description)
    }

    Component.onDestruction: {
        camera.active = false
    }
}
