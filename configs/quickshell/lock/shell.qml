pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    /**
     * Heartbeat for watchdog.sh, which restarts this shell when it stops beating.
     */
    FileView {
        id: heartbeat
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-lock-alive"
        printErrors: false
        blockLoading: false
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: heartbeat.setText(String(Date.now()))
    }

    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    /** Drives the pill-to-lock reveal. Kept off while the surface first mounts so the mask starts as the pill, then flipped on to grow it open; flipped back to collapse it before the session actually unlocks. */
    property bool revealed: false

    Auth {
        id: pamAuth
        user: root.currentUser
        onSucceeded: {
            root.revealed = false;
            collapse.restart();
        }
    }

    Timer {
        id: collapse
        interval: 640
        onTriggered: {
            sessionLock.locked = false;
            Cava.enabled = false;
            Pw.text = "";
        }
    }

    /** Fires as soon as the event loop frees after the lock surfaces are built, which is the earliest the grow can start without the fresh output dropping its first frames. */
    Timer {
        id: reveal
        interval: 1
        onTriggered: root.revealed = true
    }

    function doLock(): void {
        Pw.text = "";
        root.revealed = false;
        sessionLock.locked = true;
        Cava.enabled = true;
        reveal.restart();
    }

    /**
     * lock.sh just touches this file to skip the quarter second `qs ipc call` startup, and triggerPrimed gates out startup events so the daemon never locks itself on launch.
     */
    property bool triggerPrimed: false
    Timer {
        interval: 800
        running: true
        onTriggered: root.triggerPrimed = true
    }
    Timer {
        id: triggerFire
        interval: 60
        onTriggered: if (root.triggerPrimed)
            root.doLock()
    }
    /**
     * lock.sh reads this to confirm the compositor really locked; empty means unlocked.
     */
    FileView {
        id: lockedFlag
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-locked"
        printErrors: false
        onLoaded: if (text().length > 0 && !sessionLock.secure)
            setText("")
    }
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ricelin-lock-trigger"
        watchChanges: true
        printErrors: false
        onLoadFailed: setText("0")
        onFileChanged: triggerFire.restart()
    }



    WlSessionLock {
        id: sessionLock
        locked: false
        onSecureStateChanged: lockedFlag.setText(secure ? "1" : "")

        WlSessionLockSurface {
            id: lockSurface
            color: "#160f0a"

            LockSurface {
                anchors.fill: parent
                s: lockSurface.screen ? lockSurface.screen.height / 1080 : 1
                screenName: lockSurface.screen ? lockSurface.screen.name : ""
                auth: pamAuth
                active: root.revealed
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void {
            root.doLock();
        }
    }
}
