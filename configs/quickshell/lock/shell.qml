pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

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
     * Fast lock trigger. Spawning a fresh `qs ipc call` client to ask for the lock
     * cost a quarter second of Qt startup on the critical path; instead lock.sh just
     * touches this file and the watch fires the lock, shaving that off the delay.
     * The IPC handler stays as a fallback for any other caller.
     *
     * An external write lands as a burst of change events, so the fire is debounced
     * into one; primed gates out the startup events (including the file's own
     * creation) so the daemon never locks itself on launch.
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
