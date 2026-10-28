pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import ".."
import "../Singletons"
import "app.js" as App

/** Dropdown over `options` (strings or { label, value }); `picked(value)` fires on a choice, `fontPreview` draws each label in its own font. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property var options: []
    property var value
    property string placeholder: "Choose"
    property bool fontPreview: false
    property real minWidth: 168
    signal picked(var value)

    readonly property var opts: (options || []).map(o => (o !== null && typeof o === "object") ? o : ({ label: String(o), value: o }))
    readonly property int currentIndex: opts.findIndex(o => o.value === root.value)
    readonly property string currentLabel: currentIndex >= 0 ? opts[currentIndex].label : placeholder
    readonly property bool open: menu.opened || menu.visible
    readonly property real optH: 30 * s
    readonly property real listH: Math.min(opts.length * (optH + 1 * s), 320 * s)

    implicitWidth: Math.max(minWidth * s, chipLabel.implicitWidth + 44 * s)
    implicitHeight: 30 * s
    activeFocusOnTab: true

    function fontFor(i) {
        return fontPreview && i >= 0 && i < opts.length ? String(opts[i].value) : Theme.font;
    }

    /** Font previews switch on once the list is open: loading a few dozen font files up front made it open late. */
    property bool fontsLive: false

    property bool keyed: false
    property real chipX: 0

    function popup() {
        if (opts.length === 0)
            return;
        keyed = root.activeFocus;
        const p = root.mapToItem(null, 0, 0);
        const winH = root.Window.height;
        const need = listH + 2 * menu.padding;
        const below = winH - (p.y + root.height) - menu.margins;
        const above = p.y - menu.margins;
        menu.y = (below >= need || below >= above) ? root.height + 4 * s : -need - 4 * s;
        chipX = p.x;
        list.currentIndex = Math.max(0, currentIndex);
        menu.open();
    }

    function choose(i) {
        menu.close();
        if (i >= 0 && i < opts.length && opts[i].value !== root.value)
            root.picked(opts[i].value);
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
            popup();
            e.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8 * root.s
        color: root.open || chipArea.containsMouse ? Theme.pressBg : Theme.frameBg
        border.width: 1
        border.color: root.activeFocus || root.open ? Qt.alpha(Theme.vermLit, 0.5) : Theme.frameBorder
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            id: chipLabel
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.right: chev.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentLabel
            color: root.currentIndex >= 0 ? Theme.cream : Theme.textFaint
            elide: Text.ElideRight
            font.family: root.fontFor(root.currentIndex)
            font.pixelSize: 12.5 * root.s
        }

        GlyphIcon {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 9 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: width
            name: "chevron-down"
            stroke: 2
            color: root.open || chipArea.containsMouse ? Theme.cream : Theme.textFaint
            rotation: root.open ? 180 : 0
            Behavior on rotation { enabled: !Motion.calm; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menu.visible ? menu.close() : root.popup()
        }
    }

    /** Opens below or above, whichever has more room, right-aligned when it would spill past the window, and `margins` keeps it inside. */
    QQC.Popup {
        id: menu
        x: root.chipX + width > root.Window.width - margins ? root.width - width : 0
        width: root.fontPreview ? Math.max(root.width, 300 * root.s) : Math.max(root.width, list.contentW + 2 * padding)
        height: root.listH + 2 * padding
        padding: 5 * root.s
        margins: 8 * root.s
        focus: true
        modal: false
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: Motion.calm ? 1 : 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90; easing.type: Easing.OutCubic }
        }

        background: Item {
            RectangularShadow {
                anchors.fill: menuBg
                radius: menuBg.radius
                blur: 28 * root.s
                offset.y: 8 * root.s
                color: Qt.rgba(0, 0, 0, 0.45)
            }
            Rectangle {
                id: menuBg
                anchors.fill: parent
                radius: 11 * root.s
                color: Theme.cardTop
                border.width: 1
                border.color: Theme.border
            }
        }

        contentItem: ListView {
            id: list
            readonly property real contentW: {
                let w = 0;
                for (let i = 0; i < count; i++) {
                    const it = itemAtIndex(i);
                    if (it)
                        w = Math.max(w, it.naturalW);
                }
                return w;
            }
            clip: true
            focus: true
            spacing: 1 * root.s
            boundsBehavior: Flickable.StopAtBounds
            model: root.opts
            highlightMoveDuration: 0
            keyNavigationWraps: true

            Keys.onReturnPressed: root.choose(currentIndex)
            Keys.onEnterPressed: root.choose(currentIndex)
            Keys.onSpacePressed: root.choose(currentIndex)

            QQC.ScrollBar.vertical: AppScrollBar {
                s: root.s
            }

            WheelScroller {
                parent: list
                anchors.fill: parent
                z: 5
                s: root.s
                step: 64
                byNotch: true
                flick: list
            }

            delegate: Rectangle {
                id: optRow
                required property var modelData
                required property int index
                readonly property bool current: root.currentIndex === index
                readonly property real naturalW: optText.implicitWidth + 58 * root.s

                width: ListView.view.width
                height: root.optH
                radius: 7 * root.s
                color: optArea.pressed ? Theme.pressBg : (ListView.isCurrentItem ? Theme.frameBg : "transparent")

                Text {
                    id: optText
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * root.s
                    anchors.right: check.left
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: optRow.modelData.label
                    elide: Text.ElideRight
                    color: optRow.current || optRow.ListView.isCurrentItem ? Theme.cream : Theme.subtle
                    font.family: root.fontsLive ? root.fontFor(optRow.index) : Theme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: optRow.current ? Font.Medium : Font.Normal
                }

                GlyphIcon {
                    id: check
                    anchors.right: parent.right
                    anchors.rightMargin: 9 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s
                    height: width
                    name: "check"
                    stroke: 2.2
                    color: Theme.vermLit
                    visible: optRow.current
                }

                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: if (containsMouse) list.currentIndex = optRow.index
                    onClicked: root.choose(optRow.index)
                }
            }
        }

        onAboutToShow: root.fontsLive = false
        onOpened: {
            list.positionViewAtIndex(Math.max(0, root.currentIndex), ListView.Contain);
            if (root.fontPreview)
                Qt.callLater(() => root.fontsLive = true);
        }
        onClosed: if (root.keyed && root.visible) root.forceActiveFocus()
    }
}
