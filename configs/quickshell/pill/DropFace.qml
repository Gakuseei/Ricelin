import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * Drop a file on the resting pill: app-install.sh installs apps, fonts and wallpapers while this face narrates it.
 */
Item {
    id: root

    required property Item host
    readonly property real s: host.s
    property bool active: false
    property string stage: ""
    property string name: ""

    property var queue: []
    property bool installedAny: false
    property bool installedApp: false
    property bool failed: false
    property string kind: "app"
    property string action: "new"
    property string line: ""
    property string proto: ""
    property string pct: ""
    property int seconds: 0

    anchors.fill: parent

    function localPath(url) {
        var p = String(url);
        if (p.indexOf("file://") === 0)
            p = p.substring(7);
        return decodeURIComponent(p);
    }

    readonly property var dropExt: /\.(appimage|deb|rpm|flatpakref|zip|tgz|txz|tbz2|ttf|otf|png|jpe?g|webp)$|\.(pkg\.)?tar\.(gz|xz|bz2|zst)$/i

    function droppablePaths(urls) {
        var out = [];
        for (var i = 0; i < urls.length; i++)
            if (dropExt.test(String(urls[i])))
                out.push(localPath(urls[i]));
        return out;
    }

    function dropLabel(urls) {
        var p = localPath(urls.length ? urls[0] : "");
        return p.substring(p.lastIndexOf("/") + 1).replace(dropExt, "");
    }

    function runNext() {
        if (queue.length === 0) {
            stage = installedAny ? "done" : "fail";
            (installedAny ? doneTimer : badTimer).restart();
            return;
        }
        var next = queue.shift();
        name = next.substring(next.lastIndexOf("/") + 1).replace(dropExt, "");
        line = "";
        proto = "";
        pct = "";
        installProc.command = ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/app-install.sh", "install", next];
        installProc.running = true;
    }

    /**
     * Streams stdout so slow backends narrate live; the one tab-separated kind line carries the result.
     */
    Process {
        id: installProc
        stdout: SplitParser {
            onRead: (data) => {
                var seg = data.split("\r").pop().replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "").trim();
                if (seg.length === 0)
                    return;
                if (/^(app|native|font|wallpaper)\t/.test(seg)) {
                    root.proto = seg;
                } else {
                    root.line = seg;
                    var m = seg.match(/(\d{1,3})\s*%/);
                    if (m && Number(m[1]) <= 100)
                        root.pct = m[1] + "%";
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode === 0 && root.proto.length > 0) {
                root.installedAny = true;
                var parts = root.proto.split("\t");
                root.kind = parts[0];
                root.action = parts[2];
                if (parts[0] === "app" || parts[0] === "native")
                    root.installedApp = true;
                if (parts[0] === "font" && parts.length >= 4)
                    droppedFont.source = "file://" + parts[3];
            } else {
                root.failed = true;
            }
            root.runNext();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.stage === "installing"
        onTriggered: root.seconds++
    }

    /**
     * Registers a dropped font in this process too, so the font picker lists it without a restart.
     */
    FontLoader {
        id: droppedFont
        onStatusChanged: if (status === FontLoader.Ready) Theme.refreshFonts()
    }

    Timer {
        id: doneTimer
        interval: 1100
        onTriggered: {
            root.active = false;
            root.stage = "";
            if (root.installedApp)
                root.host.requestSurface("launcher");
        }
    }

    Timer {
        id: badTimer
        interval: 1300
        onTriggered: {
            root.active = false;
            root.stage = "";
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.host.surfaceOpen && root.stage !== "installing" && root.stage !== "done"
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            drag.acceptProposedAction();
            root.active = true;
            root.stage = root.droppablePaths(drag.urls).length > 0 ? "hover" : "bad";
            root.name = root.dropLabel(drag.urls);
        }
        onExited: {
            if (root.stage === "hover" || root.stage === "bad") {
                root.active = false;
                root.stage = "";
            }
        }
        onDropped: (drop) => {
            drop.acceptProposedAction();
            var files = root.droppablePaths(drop.urls);
            root.active = true;
            if (files.length === 0) {
                root.stage = "bad";
                root.name = root.dropLabel(drop.urls);
                badTimer.restart();
                return;
            }
            root.stage = "installing";
            root.installedAny = false;
            root.installedApp = false;
            root.failed = false;
            root.kind = "app";
            root.action = "new";
            root.seconds = 0;
            root.queue = files;
            root.runNext();
        }
    }

    Face {
        id: view
        host: root.host
        mode: "dragOver"
        anchors.margins: 11 * root.s

        readonly property bool bad: root.stage === "bad" || root.stage === "fail"
        readonly property color accent: bad ? Theme.danger : Theme.vermLit
        readonly property real brLen: 15 * root.s
        readonly property real brThick: 2 * root.s

        Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            delegate: Item {
                id: corner
                required property var modelData
                readonly property bool rightSide: modelData[0] === 1
                readonly property bool bottomSide: modelData[1] === 1
                x: rightSide ? view.width - view.brLen : 0
                y: bottomSide ? view.height - view.brLen : 0
                width: view.brLen
                height: view.brLen

                Rectangle {
                    width: view.brLen
                    height: view.brThick
                    radius: view.brThick / 2
                    color: view.accent
                    anchors.top: corner.bottomSide ? undefined : parent.top
                    anchors.bottom: corner.bottomSide ? parent.bottom : undefined
                    anchors.left: corner.rightSide ? undefined : parent.left
                    anchors.right: corner.rightSide ? parent.right : undefined
                }
                Rectangle {
                    width: view.brThick
                    height: view.brLen
                    radius: view.brThick / 2
                    color: view.accent
                    anchors.top: corner.bottomSide ? undefined : parent.top
                    anchors.bottom: corner.bottomSide ? parent.bottom : undefined
                    anchors.left: corner.rightSide ? undefined : parent.left
                    anchors.right: corner.rightSide ? parent.right : undefined
                }
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 44 * root.s
            spacing: 7 * root.s

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 26 * root.s
                height: 26 * root.s

                GlyphIcon {
                    anchors.fill: parent
                    stroke: 2
                    color: view.accent
                    name: view.bad ? "close"
                        : (root.stage === "installing" ? "reboot"
                        : (root.stage === "done" ? "check" : "download"))

                    RotationAnimation on rotation {
                        running: root.stage === "installing"
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                    onNameChanged: if (root.stage !== "installing") rotation = 0
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.stage === "bad" ? "Can't install this"
                    : root.stage === "fail" ? "Install failed"
                    : root.stage === "installing" ? "Installing"
                        + (root.pct.length > 0 ? " " + root.pct : "")
                        + (root.seconds >= 3 ? "  " + Math.floor(root.seconds / 60) + ":" + String(root.seconds % 60).padStart(2, "0") : "")
                    : root.stage === "done" ? (root.failed ? "Installed, some failed"
                        : !root.installedApp && root.kind === "wallpaper" ? "Wallpaper set"
                        : !root.installedApp && root.kind === "font" ? "Font installed"
                        : root.action === "updated" ? "Updated"
                        : root.action === "reinstalled" ? "Reinstalled" : "Installed")
                    : "Drop to install"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.stage === "installing" && root.line.length > 0 ? root.line : root.name
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }
}
