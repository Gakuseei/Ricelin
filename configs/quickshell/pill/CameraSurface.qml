import QtQuick
import QtQuick.Controls
import "Singletons"

Item {
    id: root

    property real s: 1
    property bool open: false
    property real morphCloseness: 1

    signal requestClose()

    implicitWidth: 384 * s
    implicitHeight: 430 * s
    Rectangle {
        anchors.fill: parent
        radius: 24 * s
        color: "#111111"
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 16 * s
            spacing: 12 * s

            Text {
                text: "Camera"
                color: "white"
                font.pixelSize: 18 * s
                font.bold: true
            }

            Rectangle {
                width: parent.width
                height: width * 9 / 16
                radius: 16 * s
                color: "black"
                clip: true

                CameraOverlay {
                    anchors.fill: parent
                    active: root.open
                    captureSession: CameraRec.captureSession
                }
            }

            Row {
                width: parent.width
                spacing: 10 * s

                Button {
                    text: "Photo"
                    enabled: CameraRec.cameraActive
                        && CameraRec.photoReady
                        && !CameraRec.capturingPhoto
                        && !CameraRec.videoRecording

                    onClicked: CameraRec.takePhoto()
                }

                Button {
                    text: CameraRec.videoRecording
                        ? "Stop Video"
                        : "Record Video"

                    enabled: CameraRec.cameraActive
                        && !CameraRec.capturingPhoto

                    onClicked: {
                        if (CameraRec.videoRecording)
                            CameraRec.stopVideo()
                        else
                            CameraRec.startVideo()
                    }
                }

                Item {
                    width: Math.max(0, parent.width
                        - 2 * 90 * s
                        - 20 * s)
                    height: 1
                }

                Button {
                    text: "Close"
                    onClicked: root.requestClose()
                }
            }

            Text {
                width: parent.width
                text: CameraRec.videoRecording
                    ? "Recording camera video…"
                    : (CameraRec.capturingPhoto
                        ? "Capturing photo…"
                        : "Ready")
                color: "#bbbbbb"
                font.pixelSize: 13 * s
            }
        }
    }
}
