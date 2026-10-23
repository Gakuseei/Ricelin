import QtQuick
import "Singletons"

/**
 * The resting pill: the 時 glyph (or live music bars), the clock and a running activity, or the special workspace's name.
 */
Face {
    id: face

    mode: "rest"

    readonly property real s: host.s
    readonly property alias rowWidth: restRow.implicitWidth

    /**
     * Ame's rest anchor: the 時 centre, where the idle outline condenses into the bead.
     */
    readonly property point wakePoint: {
        void host.width;
        void host.height;
        return restKanji.mapToItem(face, restKanji.width / 2, restKanji.height / 2);
    }

    Row {
        id: restRow
        anchors.centerIn: parent
        spacing: 9 * face.s

        Item {
            id: restKanji
            visible: face.host.specialView === ""
            anchors.verticalCenter: parent.verticalCenter
            width: kanjiFill.implicitWidth
            height: kanjiFill.implicitHeight

            readonly property bool barsOn: Flags.musicViz && Cava.active

            Text {
                anchors.fill: parent
                opacity: (Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                text: kanjiFill.text
                color: "transparent"
                font: kanjiFill.font
                style: Text.Outline
                styleColor: Qt.alpha(Theme.vermLit,
                    Math.min(1, (face.host.mode === "rest" || !face.host.hoverSoulGate ? 0.5 : 0) + face.host.kanjiFlash))
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            Text {
                id: kanjiFill
                opacity: (Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                text: "時"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 15 * face.s
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            GlyphIcon {
                anchors.centerIn: parent
                opacity: (!Flags.showGlyphs && !restKanji.barsOn) ? 1 : 0
                width: 17 * face.s
                height: 17 * face.s
                name: "clock"
                color: Theme.cream
                stroke: 1.7
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            MusicBars {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: kanjiFill.baseline
                s: face.s
                opacity: restKanji.barsOn ? 1 : 0
                scale: restKanji.barsOn ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }
        Text {
            visible: face.host.specialView === ""
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.hhmm
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 16 * face.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        Rectangle {
            visible: live.kind.length > 0 && face.host.specialView === ""
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14 * face.s
            color: Theme.hair
        }
        LiveActivity {
            id: live
            visible: kind.length > 0 && face.host.specialView === ""
            anchors.verticalCenter: parent.verticalCenter
            s: face.s
        }
        Text {
            visible: face.host.specialView !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: face.host.specialView
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 16 * face.s
            font.weight: Font.DemiBold
        }
    }
}
