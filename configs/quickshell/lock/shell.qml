pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    readonly property string currentUser:
        Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    readonly property string runtimeDir:
        Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    property bool revealed: false
    property bool sleepLock: false
    property bool effectRequested: false

    Auth {
        id: pamAuth
        user: root.currentUser

        onSucceeded: {
            /*
             * First return to the known-safe static state.
             * We are intentionally NOT testing an animated unlock yet.
             */
            root.effectRequested = false;
            root.revealed = false;

            // The Pill is hidden during the lock capture. Restore it only after
            // PAM authentication succeeds and the lock is actually collapsing.
            Quickshell.execDetached([
                "qs", "-c", "pill", "ipc", "call", "pill", "captureShow"
            ]);

            collapse.restart();
        }
    }

    Timer {
        id: collapse

        interval: 640

        onTriggered: {
            sessionLock.locked = false;
            Pw.text = "";
        }
    }

    Timer {
        id: reveal
        interval: 1

        onTriggered:
            root.revealed = true
    }

    Timer {
        id: effectDelay
        interval: 350

        onTriggered: {
            if (sessionLock.locked && sessionLock.secure && !root.sleepLock)
                root.effectRequested = true;
        }
    }

    function doLock(): void {
        Pw.text = "";

        root.sleepLock = false;
        root.effectRequested = false;
        root.revealed = false;

        /*
         * This is the known-good lock sequence.
         * Keep it untouched.
         */
        sessionLock.locked = true;
        reveal.restart();
    }

    function doSleepLock(): void {
        Pw.text = "";

        root.sleepLock = true;
        root.effectRequested = false;
        root.revealed = true;

        /*
         * Sleep remains completely static.
         */
        sessionLock.locked = true;
    }

    Connections {
        target: sessionLock

        function onSecureChanged() {
            if (!sessionLock.secure || !sessionLock.locked)
                return;

            if (!root.sleepLock)
                effectDelay.restart();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.doLock();
        }

        function sleepLock(): void {
            root.doSleepLock();
        }

        function reveal(): void {
            root.revealed = true;
        }
    }

    /*
     * Keep the existing fast file-trigger path.
     */
    property bool triggerPrimed: false

    Timer {
        interval: 800
        running: true

        onTriggered:
            root.triggerPrimed = true
    }

    Timer {
        id: triggerFire
        interval: 60

        onTriggered: {
            if (root.triggerPrimed)
                root.doLock();
        }
    }

    FileView {
        path:
            (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") +
            "/ricelin-lock-trigger"

        watchChanges: true
        printErrors: false

        onLoadFailed:
            setText("0")

        onFileChanged:
            triggerFire.restart()
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface
            color: "#0e1014"

            LockSurface {
                anchors.fill: parent

                s:
                    lockSurface.screen
                        ? lockSurface.screen.height / 1080
                        : 1

                screenName:
                    lockSurface.screen
                        ? lockSurface.screen.name
                        : ""

                auth: pamAuth
                active: root.revealed
                sleepLock: root.sleepLock
                effectRequested: root.effectRequested
            }
        }
    }
}
