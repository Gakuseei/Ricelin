import QtQuick
import "Singletons"

/**
 * Game mode: the pill docks into a flush top bar with the clock, the playing track and a volume chip.
 */
Face {
    id: face

    mode: "game"

    required property Item osd
    readonly property real s: host.s

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 18 * face.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9 * face.s
        opacity: Players.has ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * face.s
            height: 26 * face.s
            radius: 7 * face.s
            color: Theme.tileBg
            clip: true
            Image {
                anchors.fill: parent
                source: Players.artUrl
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: Players.title
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * face.s
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220 * face.s)
            }
            Text {
                text: Players.artist
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 10.5 * face.s
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220 * face.s)
                visible: text.length > 0
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Clock.hhmm
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 16 * face.s
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }

    /**
     * Volume and brightness stay visible as a chip while the full OSD face is parked behind game mode.
     */
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 18 * face.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9 * face.s
        opacity: face.osd.flashing && (face.osd.kind === "volume" || face.osd.kind === "brightness") ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * face.s
            height: 14 * face.s
            name: face.osd.kind === "brightness" ? "sun" : (face.osd.muted ? "speaker-off" : "speaker")
            color: face.osd.kind === "volume" && face.osd.muted ? Theme.dim : Theme.iconDim
            stroke: 1.7
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 64 * face.s
            height: 3 * face.s
            radius: 1.5 * face.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * (face.osd.kind === "brightness" ? face.osd.brightness : face.osd.volume)
                radius: parent.radius
                color: face.osd.kind === "volume" && face.osd.muted ? Theme.vermDim : Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round((face.osd.kind === "brightness" ? face.osd.brightness : face.osd.volume) * 100) + "%"
            color: face.osd.kind === "volume" && face.osd.muted ? Theme.dim : Theme.cream
            font.family: Theme.font
            font.pixelSize: 10.5 * face.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
    }
}
