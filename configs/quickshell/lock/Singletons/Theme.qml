pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color vermDeep: "#a3371f"
    readonly property color verm:     "#c0442b"
    readonly property color vermLit:  "#e0563b"
    readonly property color cream:    "#e6d6cb"
    readonly property color dim:      "#8a7d74"
    readonly property color border:   "#3a2a22"
    readonly property string font: "Inter"

    property color accent: "#c0442b"
    property real gradeIntensity: 0.5

    readonly property color text:     "#f7f0ea"
    readonly property color textDim:  "#ecdfd6"
    readonly property color fieldBg:  Qt.rgba(12 / 255, 8 / 255, 7 / 255, 0.4)
    readonly property color fieldBorder: Qt.rgba(230 / 255, 214 / 255, 203 / 255, 0.5)
    readonly property color trackBg:  Qt.rgba(1, 1, 1, 0.16)
    readonly property color scrimTop:    Qt.rgba(8 / 255, 5 / 255, 6 / 255, 0.45)
    readonly property color scrimBottom: Qt.rgba(8 / 255, 5 / 255, 6 / 255, 0.65)
}
