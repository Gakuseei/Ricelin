pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 報 INBOX surface: the notification center. Grouped per app with critical
 * entries pinned above the fold, an inline clear-all, and a silence empty
 * state; opening marks all notifications seen after a short beat so unread
 * embers register first. Exposes `desiredW` for the pill's morph and docks Ame
 * as a seam at the focused row.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    readonly property real desiredW: 330 * s

    /**
     * Row-soul focus registry. Each hoverable row reports itself here; the bead
     * docks as a glowing seam at the left edge of the focused row and hides
     * when nothing is focused.
     */
    property Item focusRowItem: null

    /**
     * Sticky: once a row has been focused the seam stays parked on it when the
     * pointer leaves, gliding to the next focused row instead of re-waking
     * from the pill centre on every hover. Cleared only when the surface
     * closes.
     */
    function reportRowHover(item, hovered) {
        if (hovered)
            focusRowItem = item;
    }

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void mainCol.implicitHeight;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    implicitHeight: mainCol.implicitHeight

    onActiveChanged: {
        if (active) {
            seenTimer.restart();
        } else {
            seenTimer.stop();
            focusRowItem = null;
        }
    }

    Timer {
        id: seenTimer
        interval: 600
        repeat: false
        onTriggered: Notifs.markAllSeen()
    }

    /**
     * Ember mark: a small flame-glow dot over a soft halo, the unread marker
     * shared by the header badge and unread notification titles.
     */
    component Ember: Item {
        id: ember
        property real size: 4 * root.s

        width: size * 2.2
        height: size * 2.2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: Theme.flameGlow
            opacity: 0.22
        }

        Rectangle {
            anchors.centerIn: parent
            width: ember.size
            height: ember.size
            radius: width / 2
            color: Theme.flameGlow
        }
    }

    /**
     * Single inbox entry: icon tile or diamond, body text, ×N coalesce badge,
     * age label that cross-fades into a dismiss glyph on hover. Critical
     * entries gain a vermilion left hairline and cream emphasis.
     */
    component NotifRow: Rectangle {
        id: nrow

        required property var entry
        property bool critical: false
        readonly property var n: entry.n

        width: parent ? parent.width : 0
        height: 26 * root.s
        radius: 7 * root.s
        color: nrowHover.hovered ? Theme.frameBg : "transparent"

        HoverHandler {
            id: nrowHover
            onHoveredChanged: root.reportRowHover(nrow, hovered)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Notifs.activateEntry(nrow.entry);
                root.requestClose();
            }
        }

        Rectangle {
            visible: nrow.critical
            anchors.left: parent.left
            anchors.leftMargin: 1 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * root.s
            height: parent.height - 10 * root.s
            radius: 999
            color: Theme.verm
        }

        Rectangle {
            id: nrowTile
            anchors.left: parent.left
            anchors.leftMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            radius: 5 * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.border

            Image {
                id: nrowImg
                anchors.fill: parent
                anchors.margins: nrow.n.image ? 0 : 2 * root.s
                source: Notifs.iconFor(nrow.n)
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: source.toString().length > 0
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !nrowImg.visible
                width: 5 * root.s
                height: 5 * root.s
                radius: 1.5 * root.s
                rotation: 45
                color: nrow.critical ? Theme.vermLit : Theme.verm
            }
        }

        Text {
            anchors.left: nrowTile.right
            anchors.leftMargin: 8 * root.s
            anchors.right: nrowRight.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: nrow.n.body.length > 0 ? nrow.n.body : nrow.n.summary
            color: nrow.critical ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: nrow.critical ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Row {
            id: nrowRight
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Text {
                visible: nrow.entry.count > 1
                anchors.verticalCenter: parent.verticalCenter
                text: "×" + nrow.entry.count
                color: nrow.critical ? Theme.vermLit : Theme.vermDim
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(nrowAge.implicitWidth, nrowX.implicitWidth)
                height: Math.max(nrowAge.implicitHeight, nrowX.implicitHeight)

                Text {
                    id: nrowAge
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: nrowHover.hovered ? 0 : 1
                    text: Notifs.ageLabel(nrow.n)
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                GlyphIcon {
                    id: nrowX
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11 * root.s
                    height: 11 * root.s
                    opacity: nrowHover.hovered ? 1 : 0
                    name: "close"
                    color: nrowXArea.containsMouse ? Theme.cream : Theme.dim
                    stroke: 1.9
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    MouseArea {
                        id: nrowXArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        enabled: nrowHover.hovered
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismissEntry(nrow.entry)
                    }
                }
            }
        }
    }

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4 * root.s

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "報"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "INBOX"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Row {
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s
                    visible: Notifs.unread > 0

                    Ember {
                        id: headerEmber
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6 * root.s

                        SequentialAnimation on opacity {
                            running: headerEmber.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 1; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.unread + " NEW"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                    }
                }

                Item {
                    width: clearRow.implicitWidth
                    height: clearRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.count > 0

                    Row {
                        id: clearRow
                        spacing: 4 * root.s

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Flags.showGlyphs
                            text: "払"
                            color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                            font.family: Theme.fontJp
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Bold
                        }
                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !Flags.showGlyphs
                            width: 11 * root.s
                            height: 11 * root.s
                            name: "trash"
                            color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                            stroke: 1.8
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CLEAR"
                            color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: 1.4 * root.s
                        }
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: clearRow
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item {
            visible: Notifs.count > 0
            width: parent.width
            height: notifFlick.height

            Flickable {
                id: notifFlick
                width: parent.width
                height: Math.min(notifCol.implicitHeight, 320 * root.s)
                contentHeight: notifCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: returnToBounds()

                Column {
                    id: notifCol
                    width: notifFlick.width
                    spacing: 6 * root.s

                    Repeater {
                        model: Notifs.groups

                        Column {
                            id: group
                            required property var modelData
                            readonly property bool expanded: Notifs.expandedApps[modelData.app] === true
                            width: notifCol.width
                            spacing: 2 * root.s

                            Repeater {
                                model: group.modelData.criticals

                                NotifRow {
                                    required property var modelData
                                    entry: modelData
                                    critical: true
                                }
                            }

                            Rectangle {
                                id: groupHead
                                width: parent.width
                                height: 32 * root.s
                                radius: 8 * root.s
                                color: headHover.hovered ? Theme.frameBg : "transparent"

                                HoverHandler {
                                    id: headHover
                                    onHoveredChanged: root.reportRowHover(groupHead, hovered)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifs.toggleExpanded(group.modelData.app)
                                }

                                Rectangle {
                                    id: headTile
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20 * root.s
                                    height: 20 * root.s
                                    radius: 6 * root.s
                                    color: Theme.tileBg
                                    border.width: 1
                                    border.color: Theme.border

                                    Image {
                                        id: headImg
                                        anchors.fill: parent
                                        anchors.margins: group.modelData.newest.image ? 0 : 3 * root.s
                                        source: Notifs.iconFor(group.modelData.newest)
                                        sourceSize.width: 40
                                        sourceSize.height: 40
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        visible: source.toString().length > 0
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: !headImg.visible
                                        width: 6 * root.s
                                        height: 6 * root.s
                                        radius: 2 * root.s
                                        rotation: 45
                                        color: Theme.verm
                                    }
                                }

                                Text {
                                    id: headName
                                    anchors.left: headTile.right
                                    anchors.leftMargin: 8 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 110 * root.s)
                                    text: group.modelData.app
                                    color: Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 9 * root.s
                                    font.weight: Font.Bold
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 1.2 * root.s
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: headCount
                                    anchors.left: headName.right
                                    anchors.leftMargin: 5 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "· " + group.modelData.count
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9 * root.s
                                }

                                Text {
                                    anchors.left: headCount.right
                                    anchors.leftMargin: 8 * root.s
                                    anchors.right: headX.left
                                    anchors.rightMargin: 8 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: group.modelData.preview.body.length > 0
                                        ? group.modelData.preview.body
                                        : group.modelData.preview.summary
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 10 * root.s
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    textFormat: Text.PlainText
                                }

                                GlyphIcon {
                                    id: headChev
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 11 * root.s
                                    height: 11 * root.s
                                    name: group.expanded ? "chevron-down" : "chevron-right"
                                    color: Theme.faint
                                    stroke: 2
                                }

                                GlyphIcon {
                                    id: headX
                                    anchors.right: headChev.left
                                    anchors.rightMargin: 7 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 11 * root.s
                                    height: 11 * root.s
                                    opacity: headHover.hovered ? 1 : 0
                                    name: "close"
                                    color: headXArea.containsMouse ? Theme.cream : Theme.dim
                                    stroke: 1.9
                                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                                    MouseArea {
                                        id: headXArea
                                        anchors.fill: parent
                                        anchors.margins: -6 * root.s
                                        enabled: headHover.hovered
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifs.dismissApp(group.modelData.app)
                                    }
                                }
                            }

                            Column {
                                visible: group.expanded
                                width: parent.width
                                spacing: 2 * root.s

                                Repeater {
                                    model: group.expanded ? group.modelData.entries : []

                                    NotifRow {
                                        required property var modelData
                                        entry: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: notifFlick
            }
        }

        Column {
            visible: Notifs.count === 0
            width: parent.width
            topPadding: 14 * root.s
            bottomPadding: 14 * root.s
            spacing: 4 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Flags.showGlyphs
                text: "静"
                color: Theme.ghost
                opacity: 0.55
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 32 * root.s
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Flags.showGlyphs ? "SILENCE" : "No notifications to display"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
                font.letterSpacing: Flags.showGlyphs ? 2.2 * root.s : 0.8 * root.s
            }
        }
    }
}
