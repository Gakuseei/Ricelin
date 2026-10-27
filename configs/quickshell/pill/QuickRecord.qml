import QtQuick
import "Singletons"

/**
 * The SUPER+D quick record on the focused monitor: pick a source, then a big countdown that cancels on click.
 */
Item {
    id: root

    required property Item host
    readonly property real s: host.s

    anchors.fill: parent

    Face {
        host: root.host
        mode: "quickChoose"
        anchors.margins: Theme.sp.xs * root.s

        SourceChooser {
            anchors.fill: parent
            s: root.s
            screenName: root.host.screenName
            screens: ScreenRec.quickScreenChoosing
            tileRadius: Theme.r.l * root.s
            onWantScreens: ScreenRec.quickScreenChoosing = true
            onResolved: {
                ScreenRec.quickChoosing = false;
                ScreenRec.quickScreenChoosing = false;
            }
            onBack: ScreenRec.quickScreenChoosing = false
        }
    }

    Face {
        host: root.host
        mode: "quickCount"

        Column {
            anchors.centerIn: parent
            spacing: Theme.sp.xxs * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ScreenRec.countdown
                color: Theme.flameGlow
                font.family: Theme.font
                font.pixelSize: 28 * root.s
                font.weight: Font.ExtraBold
                font.features: { "tnum": 1 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Get ready"
                color: Theme.textFaint
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: ScreenRec.cancel()
        }
    }
}
