import QtQuick
import "../Singletons"
import "app.js" as App

/** One setting line: `label`, `sub`, search `key`, its control as the child on the right (`block` puts it full width below); hover lights it, `flash()` marks it after a search jump. */
Item {
    id: row

    property real s: App.shell ? App.shell.s : 1
    property string label: ""
    property string sub: ""
    property string key: ""
    property bool block: false
    property bool clickable: false
    signal clicked()
    default property alias control: slot.data

    readonly property bool isAppRow: true
    readonly property bool lit: (hover.hovered && !block) || press.pressed
    property Item page: null
    property Item group: null
    property bool advanced: false

    readonly property real padX: 12 * s
    readonly property real gap: 18 * s
    readonly property real textW: textCol.implicitWidth
    readonly property bool wrapped: !block && slot.width > 0 && (slot.width + gap + 150 * s > width - 2 * padX)
    readonly property real textH: textCol.implicitHeight

    width: parent ? parent.width : implicitWidth
    implicitWidth: 400 * s
    implicitHeight: block ? (textH > 0 ? textH + 10 * s : 0) + slot.height + 20 * s
        : wrapped ? textH + 8 * s + slot.height + 18 * s
        : Math.max(50 * s, textH + 18 * s, slot.height + 16 * s)

    function findUp(flag) {
        let p = row.parent;
        while (p) {
            if (p[flag] === true)
                return p;
            p = p.parent;
        }
        return null;
    }

    function attach() {
        const pg = findUp("isAppPage");
        if (pg !== page) {
            if (page && key.length > 0)
                page.unregisterRow(key, row);
            page = pg;
            if (page && key.length > 0)
                page.registerRow(key, row);
        }
        group = findUp("isAppGroup");
        advanced = findUp("isAdvancedColumn") !== null;
    }

    function flash() {
        flashAnim.restart();
    }

    Component.onCompleted: attach()
    onParentChanged: if (parent) attach()
    Component.onDestruction: if (page && key.length > 0) page.unregisterRow(key, row)

    readonly property Item prevRow: {
        const p = row.parent;
        if (!p)
            return null;
        const c = p.children;
        let prev = null;
        for (let i = 0; i < c.length; i++) {
            if (c[i] === row)
                return prev;
            if (c[i].visible && c[i].isAppRow === true)
                prev = c[i];
        }
        return null;
    }

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: row.padX
        anchors.rightMargin: row.padX
        height: 1
        color: Theme.hairSoft
        visible: row.prevRow !== null
        opacity: row.lit || (row.prevRow && row.prevRow.lit) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: 9 * row.s
        color: press.pressed ? Theme.pressBg : Theme.frameBg
        opacity: row.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: flashRect
        anchors.fill: parent
        radius: 9 * row.s
        color: Theme.vermLit
        opacity: 0

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashRect; property: "opacity"; to: 0.2; duration: 120; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 450 }
            NumberAnimation { target: flashRect; property: "opacity"; to: 0; duration: 1300; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: press
        anchors.fill: parent
        enabled: row.clickable
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.clicked()
    }

    Column {
        id: textCol
        x: row.padX
        y: row.block || row.wrapped ? 10 * row.s : (row.height - height) / 2
        width: row.block || row.wrapped ? row.width - 2 * row.padX : Math.max(0, row.width - 2 * row.padX - slot.width - row.gap)
        spacing: 3 * row.s

        Text {
            width: parent.width
            visible: text.length > 0
            text: row.label
            color: Theme.cream
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: 13 * row.s
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: row.sub
            color: Theme.textFaint
            wrapMode: Text.WordWrap
            lineHeight: 1.1
            font.family: Theme.font
            font.pixelSize: 11.5 * row.s
        }
    }

    Item {
        id: slot
        x: row.block ? row.padX : row.width - row.padX - width
        y: row.block ? (row.textH > 0 ? textCol.y + row.textH + 10 * row.s : 10 * row.s)
            : row.wrapped ? textCol.y + textCol.height + 8 * row.s
            : (row.height - height) / 2
        width: row.block ? row.width - 2 * row.padX : childrenRect.width
        height: childrenRect.height
    }
}
