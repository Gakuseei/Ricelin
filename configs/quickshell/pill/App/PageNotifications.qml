import QtQuick
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "notifications"

    function flashOn(k) {
        return (Flags.osdOff || []).indexOf(k) < 0;
    }

    function setFlash(k, on) {
        const off = (Flags.osdOff || []).filter(o => o !== k);
        if (!on)
            off.push(k);
        Flags.osdOff = off;
    }

    function reset() {
        Flags.osdOff = [];
        Flags.osdTime = 1.0;
        Flags.notifSecs = 4;
        Flags.notifMuted = [];
    }

    component FlashRow: AppRow {
        id: fr
        property string kind: ""
        clickable: true
        onClicked: page.setFlash(fr.kind, !page.flashOn(fr.kind))
        AppToggle {
            checked: page.flashOn(fr.kind)
            onToggled: (on) => page.setFlash(fr.kind, on)
        }
    }

    AppGroup {
        title: "Media"
        hint: "The song card that drops out of the pill"

        FlashRow {
            label: "Play and pause"
            sub: "When music starts or stops"
            key: "notif.play"
            kind: "play"
        }
        FlashRow {
            label: "New song"
            sub: "When the track changes"
            key: "notif.song"
            kind: "song"
        }
    }

    AppGroup {
        title: "Pill flashes"
        hint: "Short pop-ups when something changes"

        FlashRow {
            label: "Volume"
            sub: "When you change the volume or mute"
            key: "notif.volume"
            kind: "volume"
        }
        FlashRow {
            label: "Brightness"
            sub: "When the screen gets brighter or darker"
            key: "notif.brightness"
            kind: "brightness"
        }
        FlashRow {
            label: "Workspace"
            sub: "The dots when you switch workspaces"
            key: "notif.workspace"
            kind: "workspace"
        }
        FlashRow {
            visible: Battery.present
            label: "Charging"
            sub: "When you plug in the charger"
            key: "notif.battery"
            kind: "battery"
        }
        FlashRow {
            label: "Screen recording"
            sub: "When a recording starts or stops"
            key: "notif.record"
            kind: "record"
        }
        AppRow {
            label: "How long they stay"
            sub: "Scales every flash, the song card included"
            key: "notif.osdtime"
            AppSeg {
                options: [0.5, 0.75, 1, 1.5, 2].map(v => ({ label: v + "×", value: v }))
                value: Flags.osdTime
                onPicked: (v) => Flags.osdTime = v
            }
        }
        AppRow {
            label: "Do not disturb"
            sub: "Also hides media, workspace, charging and recording. Volume and brightness still show."
            key: "notif.dnd"
            clickable: true
            onClicked: Flags.dnd = !Flags.dnd
            AppToggle {
                checked: Flags.dnd
                onToggled: (on) => Flags.dnd = on
            }
        }
    }

    AppGroup {
        title: "App notifications"
        hint: "Messages apps send, like chats and downloads"

        AppRow {
            label: "Show for"
            sub: "How long a new notification stays in the pill"
            key: "notif.secs"
            AppSeg {
                options: [3, 4, 6, 8, 12].concat([3, 4, 6, 8, 12].indexOf(Flags.notifSecs) < 0 ? [Flags.notifSecs] : [])
                    .sort((a, b) => a - b).map(v => ({ label: v + " s", value: v }))
                value: Flags.notifSecs
                onPicked: (v) => Flags.notifSecs = v
            }
        }
    }

    AppGroup {
        title: "Apps"
        hint: "Off keeps an app out of the pill, its messages still land in the inbox"

        AppRow {
            visible: Notifs.knownApps.length === 0
            label: "No apps yet"
            sub: "Apps show up here after their first notification"
            key: "notif.apps"
        }

        Repeater {
            model: Notifs.knownApps

            AppRow {
                id: appRow
                required property var modelData
                readonly property string app: String(modelData)
                label: app
                sub: Notifs.isMuted(app) ? "Only in the inbox" : "In the pill and the inbox"
                clickable: true
                onClicked: Notifs.setMuted(appRow.app, !Notifs.isMuted(appRow.app))
                AppToggle {
                    checked: !Notifs.isMuted(appRow.app)
                    onToggled: (on) => Notifs.setMuted(appRow.app, !on)
                }
            }
        }
    }
}
