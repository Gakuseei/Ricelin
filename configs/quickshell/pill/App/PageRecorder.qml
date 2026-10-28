import QtQuick
import Quickshell
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "recorder"

    readonly property string home: Quickshell.env("HOME")
    property bool folderBad: false

    function tilde(p) {
        return home.length > 0 && p.indexOf(home) === 0 ? "~" + p.slice(home.length) : p;
    }

    readonly property string shownDir: tilde(ScreenRec.outDir)

    /** Empty or the default folder stores "" so the default keeps following $HOME; anything else must be a full path. */
    function setFolder(text) {
        let t = text.trim().replace(/\/+$/, "");
        if (t === "~")
            t = home;
        else if (t.indexOf("~/") === 0)
            t = home + t.slice(1);
        if (t.length === 0 || t === ScreenRec.defaultDir) {
            folderBad = false;
            Flags.recordDir = "";
            return;
        }
        if (t.charAt(0) !== "/") {
            folderBad = true;
            App.toast("Use a full path, like ~/Videos/Clips", "error");
            return;
        }
        folderBad = false;
        Flags.recordDir = t;
    }

    function reset() {
        Flags.recordFps = 60;
        Flags.recordQuality = "high";
        Flags.recordCursor = true;
        Flags.recordMic = true;
        Flags.recordDesktop = true;
        Flags.recordCountdown = 5;
        Flags.recordDir = "";
        folderBad = false;
        folderField.text = Qt.binding(() => page.shownDir);
    }

    AppGroup {
        title: "Video"

        AppRow {
            label: "Frame rate"
            sub: "Frames per second, higher is smoother"
            key: "rec.fps"
            AppSeg {
                options: [30, 60, 120, 144].concat([30, 60, 120, 144].indexOf(Flags.recordFps) < 0 ? [Flags.recordFps] : [])
                    .sort((a, b) => a - b).map(v => ({ label: String(v), value: v }))
                value: Flags.recordFps
                onPicked: (v) => Flags.recordFps = v
            }
        }
        AppRow {
            label: "Quality"
            sub: "Higher means bigger files"
            key: "rec.quality"
            AppSeg {
                options: [
                    { label: "Medium", value: "medium" },
                    { label: "High", value: "high" },
                    { label: "Ultra", value: "ultra" },
                    { label: "Lossless", value: "lossless" }
                ]
                value: Flags.recordQuality
                onPicked: (v) => Flags.recordQuality = v
            }
        }

        advanced: [
            AppRow {
                label: "Show cursor"
                sub: "Draw the pointer into the video"
                key: "rec.cursor"
                clickable: true
                onClicked: Flags.recordCursor = !Flags.recordCursor
                AppToggle {
                    checked: Flags.recordCursor
                    onToggled: (on) => Flags.recordCursor = on
                }
            }
        ]
    }

    AppGroup {
        title: "Audio"

        AppRow {
            label: "Record microphone"
            sub: "Your default input"
            key: "rec.mic"
            clickable: true
            onClicked: Flags.recordMic = !Flags.recordMic
            AppToggle {
                checked: Flags.recordMic
                onToggled: (on) => Flags.recordMic = on
            }
        }
        AppRow {
            label: "Record desktop audio"
            sub: "Everything you hear"
            key: "rec.desktop"
            clickable: true
            onClicked: Flags.recordDesktop = !Flags.recordDesktop
            AppToggle {
                checked: Flags.recordDesktop
                onToggled: (on) => Flags.recordDesktop = on
            }
        }
    }

    AppGroup {
        title: "Start and save"

        AppRow {
            label: "Countdown"
            sub: "Seconds before recording starts"
            key: "rec.countdown"
            AppSeg {
                options: [0, 3, 5, 10].concat([0, 3, 5, 10].indexOf(Flags.recordCountdown) < 0 ? [Flags.recordCountdown] : [])
                    .sort((a, b) => a - b).map(v => ({ label: v === 0 ? "Off" : v + " s", value: v }))
                value: Flags.recordCountdown
                onPicked: (v) => Flags.recordCountdown = v
            }
        }
        AppRow {
            label: "Folder"
            sub: "Where recordings are saved"
            key: "rec.folder"
            Row {
                spacing: 8 * page.s

                AppField {
                    id: folderField
                    fieldWidth: 230
                    text: page.shownDir
                    placeholder: "~/Videos/Recordings"
                    valid: !page.folderBad
                    onEdited: page.folderBad = false
                    onAccepted: (t) => {
                        if (t.trim() !== page.shownDir)
                            page.setFolder(t);
                    }
                }
                AppButton {
                    text: "Choose…"
                    onClicked: ScreenRec.pickDir()
                }
            }
        }

        advanced: [
            AppRow {
                label: "Open the folder"
                sub: "Shows your recordings in the file manager"
                key: "rec.open"
                AppButton {
                    text: "Open"
                    onClicked: ScreenRec.openDir()
                }
            }
        ]
    }
}
