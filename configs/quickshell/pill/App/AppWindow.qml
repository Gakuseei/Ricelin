import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Hyprland
import ".."
import "../Singletons"
import "pages.js" as Pages
import "app.js" as App

/** Ricelin Settings: one floating window built on open and dropped on close; `present(page)` shows a page and raises it. */
FloatingWindow {
    id: win

    title: "Ricelin Settings"
    color: Theme.cardBot

    signal dismissed()

    readonly property var mon: Hyprland.focusedMonitor
    readonly property real monW: mon && mon.width > 0 ? mon.width / Math.max(0.1, mon.scale) : 1920
    readonly property real monH: mon && mon.height > 0 ? mon.height / Math.max(0.1, mon.scale) : 1080
    readonly property real zoom: Flags.appZoom > 0 ? Flags.appZoom : 0.85
    readonly property real s: Flags.uiScale * zoom * Math.max(720, screen ? screen.height : monH) / 1080
    property real openS: Flags.uiScale * zoom * Math.max(720, monH) / 1080
    readonly property var zoomSteps: [0.6, 0.67, 0.75, 0.8, 0.85, 0.9, 1, 1.1, 1.25, 1.5]

    implicitWidth: Math.round(Math.min(1100 * openS, monW * 0.92))
    implicitHeight: Math.round(Math.min(690 * openS, monH * 0.88))
    minimumSize: Qt.size(Math.round(Math.min(780 * openS, monW * 0.9)), Math.round(Math.min(480 * openS, monH * 0.8)))

    property string current: ""
    property var history: []
    property int histIndex: -1
    property var pending: null
    property real keepScroll: -1

    readonly property real sidebarW: 210 * s
    readonly property real barH: 54 * s
    readonly property color barBg: Qt.rgba(Theme.cardTop.r * 0.86 + Theme.cardBot.r * 0.14,
                                           Theme.cardTop.g * 0.86 + Theme.cardBot.g * 0.14,
                                           Theme.cardTop.b * 0.86 + Theme.cardBot.b * 0.14, 1)

    Component.onCompleted: {
        App.shell = win;
        openS = openS;
        implicitWidth = implicitWidth;
        implicitHeight = implicitHeight;
        minimumSize = minimumSize;
        Qt.callLater(() => {
            if (win.current.length === 0)
                win.go(Pages.home);
        });
    }
    Component.onDestruction: if (App.shell === win) App.shell = null

    onClosed: dismissed()

    function present(page) {
        const id = Pages.pages[page] ? page : "";
        if (id.length > 0 && id !== current)
            go(id);
        else if (current.length === 0)
            go(Pages.home);
        if (backingWindowVisible)
            raise();
    }

    function raise() {
        Hyprland.dispatch('hl.dsp.focus({ window = "title:^(Ricelin Settings)$" })');
    }

    function go(id, noPush) {
        if (!Pages.pages[id] || id === current)
            return;
        if (!noPush) {
            history = history.slice(0, histIndex + 1).concat([id]);
            histIndex = history.length - 1;
        }
        current = id;
    }

    function back() {
        if (histIndex <= 0)
            return;
        histIndex--;
        current = history[histIndex];
    }

    function forward() {
        if (histIndex >= history.length - 1)
            return;
        histIndex++;
        current = history[histIndex];
    }

    function openPage(id, key, tab) {
        if (!Pages.pages[id])
            id = Pages.home;
        pending = { key: key || "", tab: tab || "" };
        if (id === current && pageLoader.item)
            applyPending();
        else
            go(id);
    }

    function applyPending() {
        const p = pending;
        pending = null;
        const pg = pageLoader.item;
        if (!p || !pg)
            return;
        if (p.tab.length > 0 && pg.tabs && pg.tabs.indexOf(p.tab) >= 0)
            pg.currentTab = p.tab;
        if (p.key.length > 0)
            Qt.callLater(() => {
                if (pageLoader.item === pg)
                    pg.reveal(p.key);
            });
    }

    function toast(msg, kind) {
        toastItem.show(msg, kind);
    }

    function focusHome() {
        keySink.forceActiveFocus();
    }

    property Item scrollTarget: null
    property bool scrollFlash: false

    function scrollToItem(item, doFlash) {
        scrollTarget = item;
        scrollFlash = doFlash === true;
        scrollTimer.restart();
    }

    Timer {
        id: scrollTimer
        interval: 60
        onTriggered: {
            const it = win.scrollTarget;
            win.scrollTarget = null;
            if (!it)
                return;
            const y = it.mapToItem(scroller.contentItem, 0, 0).y;
            const pg = pageLoader.item;
            let top = 24 * win.s;
            if (pg && pg.wantsPreview && pg.stage) {
                const stageEnd = pg.stage.mapToItem(scroller.contentItem, 0, pg.stage.height).y;
                if (y - top > stageEnd - 30 * win.s)
                    top += slim.height;
            }
            const visTop = scroller.contentY + top;
            const visBottom = scroller.contentY + scroller.height - 16 * win.s;
            if (y < visTop || y + it.height > visBottom) {
                const to = Math.max(0, Math.min(scroller.contentHeight - scroller.height, y - top));
                if (Motion.calm) {
                    scroller.contentY = to;
                } else {
                    scrollAnim.to = to;
                    scrollAnim.restart();
                }
            }
            if (win.scrollFlash && typeof it.flash === "function")
                it.flash();
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: scroller
        property: "contentY"
        duration: 380
        easing.type: Easing.OutCubic
    }

    function zoomTo(z) {
        Flags.appZoom = z;
        toast("Zoom " + Math.round(z * 100) + "%");
    }

    /** One step along `zoomSteps`, starting from the nearest step to the current zoom. */
    function zoomStep(dir) {
        const steps = zoomSteps;
        let i = 0;
        for (let k = 1; k < steps.length; k++) {
            if (Math.abs(steps[k] - zoom) < Math.abs(steps[i] - zoom))
                i = k;
        }
        const n = Math.max(0, Math.min(steps.length - 1, i + dir));
        if (steps[n] !== zoom)
            zoomTo(steps[n]);
    }

    function handleKey(e) {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        const alt = (e.modifiers & Qt.AltModifier) !== 0;
        if (e.key === Qt.Key_Escape) {
            if (search.text.length > 0) {
                search.clear();
                focusHome();
            } else if (!(pageLoader.item && pageLoader.item.cancel(false))) {
                dismissed();
            }
        } else if (ctrl && e.key === Qt.Key_F) {
            search.focusField();
        } else if (ctrl && (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)) {
            zoomStep(1);
        } else if (ctrl && e.key === Qt.Key_Minus) {
            zoomStep(-1);
        } else if (ctrl && e.key === Qt.Key_0) {
            zoomTo(0.85);
        } else if (alt && e.key === Qt.Key_Left) {
            back();
        } else if (alt && e.key === Qt.Key_Right) {
            forward();
        } else {
            return;
        }
        e.accepted = true;
    }

    AppUndo {
        id: undo
        onReverted: {
            win.toast("Reverted all changes");
            reloadTimer.restart();
        }
    }

    /** One palette follower for the whole window, so a change, Undo or Reset on any page re-runs wallcolors once. */
    PillPalette {}

    /** Pages re-read their files after an Undo by loading afresh at the same scroll spot. */
    Timer {
        id: reloadTimer
        interval: 650
        onTriggered: {
            if (!pageLoader.item)
                return;
            win.keepScroll = scroller.contentY;
            pageLoader.active = false;
            pageLoader.active = true;
        }
    }

    FocusScope {
        id: home
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => win.handleKey(e)

        Item {
            id: keySink
            focus: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
        }

        AppSidebar {
            id: sidebar
            y: win.barH
            width: win.sidebarW
            height: parent.height - y
            s: win.s
            current: win.current
            onPicked: (id) => win.go(id)
        }

        Item {
            id: main
            x: win.sidebarW
            y: win.barH
            width: parent.width - x
            height: parent.height - y
            clip: true

            Flickable {
                id: scroller
                anchors.fill: parent
                contentWidth: width
                contentHeight: pageBox.height + 56 * win.s
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                QQC.ScrollBar.vertical: AppScrollBar {
                    s: win.s
                }

                WheelScroller {
                    width: scroller.width
                    height: Math.max(scroller.height, scroller.contentHeight)
                    s: win.s
                    step: 110
                    byNotch: true
                    flick: scroller
                }

                Item {
                    id: pageBox
                    x: 30 * win.s
                    width: scroller.width - 60 * win.s
                    height: pageLoader.item ? pageLoader.item.implicitHeight : 0

                    Loader {
                        id: pageLoader
                        width: parent.width
                        source: win.current.length > 0 ? Pages.pages[win.current].file : ""
                        opacity: 0
                        onSourceChanged: win.keepScroll = -1
                        onLoaded: {
                            scrollAnim.stop();
                            scroller.contentY = win.keepScroll >= 0 ? Math.min(win.keepScroll, Math.max(0, scroller.contentHeight - scroller.height)) : 0;
                            win.keepScroll = -1;
                            pageIn.restart();
                            if (win.pending)
                                win.applyPending();
                        }
                        transform: Translate {
                            id: pageShift
                        }
                    }

                    ParallelAnimation {
                        id: pageIn
                        NumberAnimation { target: pageLoader; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        NumberAnimation { target: pageShift; property: "y"; from: Motion.calm ? 0 : 6 * win.s; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                id: slim
                readonly property Item pg: pageLoader.item
                readonly property Item stage: pg && pg.wantsPreview ? pg.stage : null
                readonly property real stageEnd: {
                    void scroller.contentY;
                    void pageBox.height;
                    return stage ? stage.mapToItem(main, 0, stage.height).y : 1e9;
                }
                readonly property bool show: stage !== null && stageEnd < 30 * win.s

                width: parent.width
                height: 58 * win.s
                z: 5
                color: win.barBg
                opacity: show ? 1 : 0
                visible: opacity > 0.01
                enabled: show
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                transform: Translate {
                    y: slim.show || Motion.calm ? 0 : -8 * win.s
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.hairSoft
                }

                Rectangle {
                    x: 30 * win.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: chip.implicitWidth + 16 * win.s
                    height: chip.implicitHeight + 8 * win.s
                    radius: 6 * win.s
                    color: Theme.frameBg

                    Text {
                        id: chip
                        anchors.centerIn: parent
                        text: "Preview"
                        color: Theme.textFaint
                        font.family: Theme.font
                        font.pixelSize: 11 * win.s
                        font.weight: Font.Medium
                    }
                }

                AppEdgeFade {
                    id: slimFade
                    y: 0
                    x: 110 * win.s
                    width: parent.width - 220 * win.s
                    height: implicitHeight
                    s: win.s
                    pad: 10 * win.s

                    HoverHandler {
                        id: slimHover
                    }

                    StagePill {
                        mode: slimHover.hovered ? "hover" : "rest"
                        s: win.s
                        interactive: slimHover.hovered
                        animated: true
                    }
                }
            }
        }

        Item {
            id: topBar
            width: parent.width
            height: win.barH
            z: 10

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.hairSoft
            }

            Item {
                id: brand
                width: win.sidebarW
                height: parent.height

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Theme.hairSoft
                }

                Row {
                    x: 22 * win.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * win.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Flags.showGlyphs
                        text: "設"
                        color: Theme.cream
                        font.family: Theme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 17 * win.s
                    }
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Flags.showGlyphs
                        width: 16 * win.s
                        height: width
                        name: "cog"
                        color: Theme.cream
                        stroke: 1.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Settings"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * win.s
                        font.weight: Font.DemiBold
                    }
                }
            }

            Row {
                id: nav
                anchors.left: brand.right
                anchors.leftMargin: 14 * win.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * win.s

                NavButton {
                    glyph: "chevron-left"
                    enabled: win.histIndex > 0
                    onTapped: win.back()
                }
                NavButton {
                    glyph: "chevron-right"
                    enabled: win.histIndex < win.history.length - 1
                    onTapped: win.forward()
                }
            }

            AppSearch {
                id: search
                anchors.left: nav.right
                anchors.leftMargin: 10 * win.s
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(340 * win.s, undoBtn.x - x - 16 * win.s)
                height: 32 * win.s
                s: win.s
                resultsWidth: Math.min(470 * win.s, win.width - x - 16 * win.s)
                maxResultsHeight: Math.min(470 * win.s, win.height - win.barH - 30 * win.s)
                onChosen: (e) => win.openPage(e.page, e.key, e.tab)
                onLeave: win.focusHome()
            }

            AppButton {
                id: undoBtn
                anchors.right: parent.right
                anchors.rightMargin: 14 * win.s
                anchors.verticalCenter: parent.verticalCenter
                s: win.s
                icon: "undo"
                text: "Undo"
                enabled: undo.changed
                onClicked: undo.revert()
            }
        }

        /** While the search owns the keyboard, a press anywhere else hands focus back and still reaches what was pressed. */
        MouseArea {
            anchors.fill: parent
            z: 9
            enabled: search.focused
            onPressed: (mouse) => {
                const p = mapToItem(search, mouse.x, mouse.y);
                if (p.x < 0 || p.y < 0 || p.x > search.width || p.y > search.height)
                    win.focusHome();
                mouse.accepted = false;
            }
        }

        /** A press beside a page's open form closes it when nothing in it changed; that press does nothing else, like a popover. */
        MouseArea {
            anchors.fill: parent
            z: 8
            enabled: !!pageLoader.item && pageLoader.item.activeForm !== null
            onPressed: (mouse) => {
                const f = pageLoader.item.activeForm;
                const p = mapToItem(f, mouse.x, mouse.y);
                const inside = p.x >= 0 && p.y >= 0 && p.x <= f.width && p.y <= f.height;
                mouse.accepted = !inside && mouse.y > win.barH && mouse.x > win.sidebarW && pageLoader.item.cancel(true);
            }
        }

        AppToast {
            id: toastItem
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22 * win.s
            z: 20
            s: win.s
        }

        MouseArea {
            anchors.fill: parent
            z: 30
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: (mouse) => mouse.button === Qt.BackButton ? win.back() : win.forward()
            onWheel: (wheel) => {
                if (!(wheel.modifiers & Qt.ControlModifier)) {
                    wheel.accepted = false;
                    return;
                }
                wheel.accepted = true;
                zoomAcc += wheel.angleDelta.y;
                if (Math.abs(zoomAcc) >= 120) {
                    win.zoomStep(zoomAcc > 0 ? 1 : -1);
                    zoomAcc = 0;
                }
            }
            property real zoomAcc: 0
        }
    }

    component NavButton: Rectangle {
        id: nb
        property string glyph: ""
        signal tapped()
        width: 30 * win.s
        height: width
        radius: 8 * win.s
        color: nbArea.containsMouse && nb.enabled ? Theme.frameBg : "transparent"
        opacity: enabled ? 1 : 0.3

        GlyphIcon {
            anchors.centerIn: parent
            width: 16 * win.s
            height: width
            name: nb.glyph
            stroke: 2
            color: nbArea.containsMouse && nb.enabled ? Theme.cream : Theme.iconDim
        }

        MouseArea {
            id: nbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: nb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: nb.tapped()
        }
    }
}
