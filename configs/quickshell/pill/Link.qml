pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * 報 Inbox: notifications grouped per app with criticals pinned on top; opening marks them seen after a beat.
 */
PillSurface {
    id: root

    mTop: Theme.inset.top
    mLeft: Theme.inset.side
    mRight: Theme.inset.side
    mBottom: Theme.inset.bottom

    readonly property real desiredW: 330 * s
    readonly property int collapseMs: 220
    readonly property int fadeMs: 120

    /**
     * Inbox rows are keyed by app, so a new notification updates its group in place instead of rebuilding the list.
     */
    readonly property var groupByApp: {
        var m = {};
        for (var i = 0; i < Notifs.groups.length; i++)
            m[Notifs.groups[i].app] = Notifs.groups[i];
        return m;
    }
    readonly property var noGroup: ({ app: "", count: 0, newest: {}, preview: { body: "", summary: "" }, criticals: [], entries: [] })

    /**
     * The seam stays parked on the last hovered row and glides to the next one; it clears when the surface closes.
     */
    property Item focusRowItem: null
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
     * One inbox entry; its age turns into a dismiss glyph on hover, and a dismissed row folds away before it is removed.
     */
    component NotifRow: Rectangle {
        id: nrow

        required property var entry
        property bool critical: false
        readonly property var n: entry.n
        property bool leaving: false

        function dismiss() {
            if (leaving)
                return;
            leaving = true;
            leaveAnim.start();
        }

        width: parent ? parent.width : 0
        height: 26 * root.s
        radius: Theme.r.s * root.s
        clip: leaving
        color: nrowPress.pressed ? Theme.pressBg : (nrowHover.hovered ? Theme.frameBg : "transparent")
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

        SequentialAnimation {
            id: leaveAnim
            ParallelAnimation {
                NumberAnimation { target: nrow; property: "height"; to: 0; duration: root.collapseMs; easing.type: Easing.OutCubic }
                NumberAnimation { target: nrow; property: "opacity"; to: 0; duration: root.fadeMs; easing.type: Easing.OutCubic }
            }
            ScriptAction { script: Notifs.dismissEntry(nrow.entry) }
        }
        Component.onDestruction: if (leaveAnim.running) Notifs.dismissEntry(entry)

        HoverHandler {
            id: nrowHover
            onHoveredChanged: root.reportRowHover(nrow, hovered)
        }

        MouseArea {
            id: nrowPress
            anchors.fill: parent
            enabled: !nrow.leaving
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
            radius: Theme.r.full
            color: Theme.verm
        }

        Rectangle {
            id: nrowTile
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            radius: Theme.r.xs * root.s
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
            anchors.leftMargin: Theme.sp.s * root.s
            anchors.right: nrowRight.left
            anchors.rightMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.plain(nrow.n.body.length > 0 ? nrow.n.body : nrow.n.summary)
            color: nrow.critical ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: Theme.fs.meta * root.s
            font.weight: nrow.critical ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Row {
            id: nrowRight
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp.s * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp.s * root.s

            Text {
                visible: nrow.entry.count > 1
                anchors.verticalCenter: parent.verticalCenter
                text: "×" + nrow.entry.count
                color: nrow.critical ? Theme.vermLit : Theme.vermDim
                font.family: Theme.font
                font.pixelSize: Theme.fs.meta * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
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
                    color: Theme.textFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fs.meta * root.s
                    font.features: { "tnum": 1 }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                }

                GlyphIcon {
                    id: nrowX
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11 * root.s
                    height: 11 * root.s
                    opacity: nrowHover.hovered ? 1 : 0
                    scale: nrowXArea.pressed && !Motion.calm ? 0.85 : 1
                    name: "close"
                    color: nrowXArea.containsMouse ? Theme.cream : Theme.textFaint
                    stroke: 1.9
                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: nrowXArea
                        anchors.fill: parent
                        anchors.margins: -Theme.sp.s * root.s
                        enabled: nrowHover.hovered && !nrow.leaving
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nrow.dismiss()
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
        spacing: Theme.sp.s * root.s

        SurfaceHeader {
            s: root.s
            glyph: "報"
            title: "Inbox"

            Row {
                x: parent.width - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp.s * root.s

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp.xs * root.s
                    visible: Notifs.unread > 0

                    Ember {
                        id: headerEmber
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6 * root.s

                        SequentialAnimation on opacity {
                            running: headerEmber.visible && !Motion.calm
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 1; duration: Motion.heat; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.55; duration: Motion.heat; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.unread + " new"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fs.label * root.s
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Theme.labelTracking * root.s
                    }
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.count > 0
                    s: root.s
                    kind: "ghost"
                    text: "Clear all"
                    onClicked: Notifs.clearAll()
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
                    spacing: Theme.sp.xs * root.s

                    Repeater {
                        model: ScriptModel {
                            values: Notifs.groups.map(g => g.app)
                        }

                        Column {
                            id: group
                            required property string modelData
                            readonly property var g: root.groupByApp[modelData] || root.noGroup
                            readonly property bool expanded: Notifs.expandedApps[modelData] === true
                            property bool leaving: false

                            function dismiss() {
                                if (leaving)
                                    return;
                                leaving = true;
                                groupLeave.start();
                            }

                            width: notifCol.width
                            spacing: Theme.sp.xxs * root.s
                            clip: leaving

                            SequentialAnimation {
                                id: groupLeave
                                ParallelAnimation {
                                    NumberAnimation { target: group; property: "height"; to: 0; duration: root.collapseMs; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: group; property: "opacity"; to: 0; duration: root.fadeMs; easing.type: Easing.OutCubic }
                                }
                                ScriptAction { script: Notifs.dismissApp(group.g.app) }
                            }
                            Component.onDestruction: if (groupLeave.running) Notifs.dismissApp(g.app)

                            Repeater {
                                model: group.g.criticals

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
                                radius: Theme.r.s * root.s
                                color: headPress.pressed ? Theme.pressBg : (headHover.hovered ? Theme.frameBg : "transparent")
                                Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                HoverHandler {
                                    id: headHover
                                    onHoveredChanged: root.reportRowHover(groupHead, hovered)
                                }

                                MouseArea {
                                    id: headPress
                                    anchors.fill: parent
                                    enabled: !group.leaving
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Notifs.toggleExpanded(group.g.app)
                                }

                                Rectangle {
                                    id: headTile
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20 * root.s
                                    height: 20 * root.s
                                    radius: Theme.r.s * root.s
                                    color: Theme.tileBg
                                    border.width: 1
                                    border.color: Theme.border

                                    Image {
                                        id: headImg
                                        anchors.fill: parent
                                        anchors.margins: group.g.newest.image ? 0 : 3 * root.s
                                        source: Notifs.iconFor(group.g.newest)
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
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 110 * root.s)
                                    text: group.g.app
                                    color: Theme.textFaint
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fs.label * root.s
                                    font.weight: Font.Bold
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: Theme.labelTracking * root.s
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                Text {
                                    id: headCount
                                    anchors.left: headName.right
                                    anchors.leftMargin: Theme.sp.xs * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "· " + group.g.count
                                    color: Theme.textFaint
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fs.label * root.s
                                    font.weight: Font.Bold
                                    font.features: { "tnum": 1 }
                                }

                                Text {
                                    anchors.left: headCount.right
                                    anchors.leftMargin: Theme.sp.s * root.s
                                    anchors.right: headX.left
                                    anchors.rightMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Notifs.plain(group.g.preview.body.length > 0 ? group.g.preview.body : group.g.preview.summary)
                                    color: Theme.textFaint
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fs.meta * root.s
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    textFormat: Text.PlainText
                                }

                                GlyphIcon {
                                    id: headChev
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 11 * root.s
                                    height: 11 * root.s
                                    name: "chevron-right"
                                    rotation: group.expanded ? 90 : 0
                                    color: Theme.faint
                                    stroke: 2
                                    Behavior on rotation {
                                        enabled: !Motion.calm
                                        NumberAnimation { duration: Motion.glide; easing.type: Easing.OutCubic }
                                    }
                                }

                                GlyphIcon {
                                    id: headX
                                    anchors.right: headChev.left
                                    anchors.rightMargin: Theme.sp.s * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 11 * root.s
                                    height: 11 * root.s
                                    opacity: headHover.hovered ? 1 : 0
                                    scale: headXArea.pressed && !Motion.calm ? 0.85 : 1
                                    name: "close"
                                    color: headXArea.containsMouse ? Theme.cream : Theme.textFaint
                                    stroke: 1.9
                                    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                                    MouseArea {
                                        id: headXArea
                                        anchors.fill: parent
                                        anchors.margins: -Theme.sp.s * root.s
                                        enabled: headHover.hovered && !group.leaving
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: group.dismiss()
                                    }
                                }
                            }

                            /**
                             * The entries grow open with the list instead of jumping ahead of the pill's shape.
                             */
                            Item {
                                id: entriesBox
                                readonly property bool populated: group.expanded || height > 0.5
                                width: parent.width
                                height: group.expanded ? entriesCol.implicitHeight : 0
                                visible: height > 0.5
                                clip: true
                                Behavior on height { NumberAnimation { duration: Motion.glide; easing.type: Easing.OutCubic } }

                                Column {
                                    id: entriesCol
                                    width: parent.width
                                    spacing: Theme.sp.xxs * root.s

                                    Repeater {
                                        model: entriesBox.populated ? group.g.entries : []

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
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: notifFlick
            }
        }

        EmptyState {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Notifs.count === 0
            s: root.s
            glyph: "inbox"
            text: "No notifications"
        }
    }
}
