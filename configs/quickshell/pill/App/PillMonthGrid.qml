pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "app.js" as App

/** This month as a small calendar in the chosen language, starting on the chosen weekday, today marked. */
Rectangle {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property string lang: Flags.dateLang
    property bool sundayFirst: Flags.weekStart === "sun"

    readonly property var today: Clock.now || new Date()
    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    readonly property int lead: {
        const first = new Date(year, month, 1).getDay();
        return sundayFirst ? first : (first + 6) % 7;
    }
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property var heads: {
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(Clock.weekday((i + (sundayFirst ? 0 : 1)) % 7, lang));
        return out;
    }
    readonly property var cells: {
        const out = [];
        for (let i = 0; i < lead; i++)
            out.push(0);
        for (let d = 1; d <= days; d++)
            out.push(d);
        return out;
    }
    readonly property real cell: 30 * s

    implicitWidth: 7 * cell + 24 * s
    implicitHeight: col.implicitHeight + 22 * s
    radius: 12 * s
    color: Qt.rgba(0, 0, 0, 0.12)
    border.width: 1
    border.color: Theme.frameBorder

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        spacing: 6 * root.s

        Text {
            leftPadding: 4 * root.s
            text: Qt.locale(Clock.localeName(root.lang)).standaloneMonthName(root.month, Locale.LongFormat) + " " + root.year
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
        }

        Grid {
            columns: 7

            Repeater {
                model: root.heads

                Text {
                    required property string modelData
                    width: root.cell
                    height: 20 * root.s
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                }
            }

            Repeater {
                model: root.cells

                Rectangle {
                    id: day
                    required property int modelData
                    required property int index
                    readonly property bool isToday: modelData === root.today.getDate()
                    readonly property bool weekend: {
                        const dow = (index + (root.sundayFirst ? 0 : 1)) % 7;
                        return dow === 0 || dow === 6;
                    }
                    width: root.cell
                    height: 24 * root.s
                    radius: 6 * root.s
                    color: isToday ? Qt.alpha(Theme.onGlow, 0.16) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        visible: day.modelData > 0
                        text: day.modelData
                        color: day.isToday ? Theme.todayWarm : (day.weekend ? Theme.dim : Theme.subtle)
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
