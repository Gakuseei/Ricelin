import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: bar

    required property var screen
    property string screenName: ""
    property real s: 1
    property var barWindow

    readonly property color vermLit: "#e0563b"
    readonly property color cream: "#e6d6cb"
    readonly property color dim: "#8a7d74"
    readonly property color hair: Qt.rgba(150 / 255, 172 / 255, 212 / 255, 0.16)
    readonly property color sheen: Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.07)
    readonly property color barTop: "#2e231b"
    readonly property color barBot: "#221813"
    readonly property color barBorder: "#3a2a22"

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 22
        border.width: 1
        border.color: bar.barBorder
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: bar.barTop }
            GradientStop { position: 1.0; color: bar.barBot }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 1
            color: bar.sheen
        }

        Item {
            id: leftZone
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12 * bar.s
            implicitWidth: leftRow.implicitWidth
            width: leftRow.implicitWidth

            RowLayout {
                id: leftRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * bar.s

                Item {
                    Layout.preferredWidth: 18 * bar.s
                    Layout.preferredHeight: 18 * bar.s

                    Image {
                        id: toriiImg
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/icons/torii.svg")
                        sourceSize.width: 96
                        sourceSize.height: 96
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: false
                    }

                    MultiEffect {
                        source: toriiImg
                        anchors.fill: toriiImg
                        colorization: 1.0
                        colorizationColor: bar.vermLit
                    }
                }

                Workspaces {
                    screenName: bar.screenName
                    s: bar.s
                }
            }
        }

        Clock {
            id: clock
            anchors.centerIn: parent
            s: bar.s
            barWindow: bar.barWindow
        }

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12 * bar.s
            spacing: 8 * bar.s

            Mpris {
                s: bar.s
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 16 * bar.s
                Layout.alignment: Qt.AlignVCenter
                color: bar.hair
            }

            RowLayout {
                spacing: 2 * bar.s

                Minimized {
                    s: bar.s
                }

                Tray {
                    s: bar.s
                    barWindow: bar.barWindow
                }

                SidebarButton {
                    s: bar.s
                }

                Power {
                    s: bar.s
                    barWindow: bar.barWindow
                }
            }
        }
    }
}
