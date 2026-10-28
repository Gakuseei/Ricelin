pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import ".."
import "../Singletons"
import "app.js" as App

/** Read-only list of the keyboards and mice in sysfs with the USB polling rate of their boot interface; devices behind a receiver say so. */
Item {
    id: root

    property real s: App.shell ? App.shell.s : 1
    property var devices: []
    property bool scanned: false

    width: parent ? parent.width : implicitWidth
    implicitWidth: 400 * s
    implicitHeight: col.implicitHeight

    readonly property string script: [
        "for u in /sys/bus/usb/devices/*; do",
        "  [ -r \"$u/idVendor\" ] || continue; b=${u##*/}; kinds=''; iv=''",
        "  for i in \"$u/$b\":*; do",
        "    [ \"$(cat \"$i/bInterfaceClass\" 2>/dev/null)\" = 03 ] && [ \"$(cat \"$i/bInterfaceSubClass\" 2>/dev/null)\" = 01 ] || continue",
        "    p=$(cat \"$i/bInterfaceProtocol\"); [ \"$p\" = 01 ] && kinds=\"${kinds}k\"; [ \"$p\" = 02 ] && kinds=\"${kinds}m\"",
        "    for e in \"$i\"/ep_8*; do [ -z \"$iv\" ] && [ -r \"$e/interval\" ] && iv=$(cat \"$e/interval\"); done",
        "  done",
        "  [ -n \"$kinds\" ] || continue; paired=''",
        "  for n in \"$u/$b\":*/*:*.*/*:*.*/input/input*/name; do",
        "    [ -r \"$n\" ] || continue; r=$(cat \"${n%/name}/capabilities/rel\" 2>/dev/null)",
        "    if [ \"${r:-0}\" != 0 ]; then t=m; else t=k; fi; paired=\"$paired$t:$(cat \"$n\");\"",
        "  done",
        "  printf 'usb\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$kinds\" \"$iv\" \"$(cat \"$u/manufacturer\" 2>/dev/null)\" \"$(cat \"$u/product\" 2>/dev/null)\" \"$paired\"",
        "done",
        "for n in /sys/class/input/input*/name; do",
        "  case \"$(readlink -f \"${n%/name}\")\" in */bluetooth/*) ;; *) continue ;; esac",
        "  r=$(cat \"${n%/name}/capabilities/rel\" 2>/dev/null); ev=$(cat \"${n%/name}/capabilities/ev\" 2>/dev/null)",
        "  if [ \"${r:-0}\" != 0 ]; then t=m; elif [ $(( 0x${ev:-0} & 0x100000 )) != 0 ]; then t=k; else continue; fi",
        "  printf 'bt\\t%s\\t\\t\\t%s\\t\\n' \"$t\" \"$(cat \"$n\")\"",
        "done"
    ].join("\n")

    /** sysfs gives the endpoint interval as "125us" or "1ms"; the rate is its inverse. */
    function hz(iv) {
        const m = /^([\d.]+)(us|ms)$/.exec(String(iv).trim());
        if (!m)
            return 0;
        const n = parseFloat(m[1]);
        return n > 0 ? Math.round((m[2] === "us" ? 1e6 : 1e3) / n) : 0;
    }

    function kindOf(code, name) {
        if (/tablet|intuos|wacom|huion|xp-pen|ugee/i.test(name))
            return "tablet";
        return code === "m" ? "mouse" : "keyboard";
    }

    function fullName(vendor, product) {
        const brand = String(vendor).replace(/[,.].*$/, "").trim().split(/\s+/)[0] || "";
        if (brand.length === 0 || product.toLowerCase().indexOf(brand.toLowerCase()) === 0)
            return product;
        return brand + " " + product;
    }

    function parse(text) {
        const out = [];
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].split("\t");
            if (f.length < 6)
                continue;
            if (f[0] === "bt") {
                if (/avrcp|headset|headphone|buds|airpods|speaker/i.test(f[4]))
                    continue;
                out.push({ name: f[4], kind: kindOf(f[1], f[4]), link: "Bluetooth" });
                continue;
            }
            const vendor = f[3], product = f[4];
            const paired = f[5].split(";").filter(p => p.indexOf(":") > 0);
            if (paired.length > 0 || /receiver|dongle|wireless|2\.4g/i.test(product)) {
                if (paired.length === 0)
                    out.push({ name: fullName(vendor, product), kind: kindOf(f[1].charAt(0), product), link: "wireless receiver" });
                for (let j = 0; j < paired.length; j++) {
                    const name = paired[j].slice(2);
                    out.push({ name: name, kind: kindOf(paired[j].charAt(0), name), link: "wireless receiver" });
                }
                continue;
            }
            const rate = hz(f[2]);
            const name = fullName(vendor, product);
            out.push({ name: name, kind: kindOf(f[1].charAt(0), name), link: rate > 0 ? rate + " Hz polling" : "USB" });
        }
        const order = { keyboard: 0, mouse: 1, tablet: 2 };
        return out.sort((a, b) => (order[a.kind] - order[b.kind]) || a.name.localeCompare(b.name));
    }

    function rescan() {
        scan.running = true;
    }

    Process {
        id: scan
        running: true
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                root.devices = root.parse(this.text);
                root.scanned = true;
            }
        }
    }

    Column {
        id: col
        width: parent.width

        Text {
            width: parent.width
            visible: root.devices.length === 0
            topPadding: 4 * root.s
            bottomPadding: 4 * root.s
            text: root.scanned ? "No keyboard or mouse found" : "Looking for devices…"
            color: Theme.textFaint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Repeater {
            model: root.devices

            Item {
                id: dev
                required property var modelData
                required property int index
                width: col.width
                height: 46 * root.s

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hairSoft
                    visible: dev.index > 0
                }

                Rectangle {
                    id: tile
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * root.s
                    height: width
                    radius: 9 * root.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.hairSoft

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: width
                        name: dev.modelData.kind === "keyboard" ? "keyboard" : (dev.modelData.kind === "tablet" ? "cursor" : "mouse")
                        color: Theme.iconDim
                    }
                }

                Column {
                    anchors.left: tile.right
                    anchors.leftMargin: 12 * root.s
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: dev.modelData.name
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: dev.modelData.kind + " · " + dev.modelData.link
                        color: Theme.textFaint
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 11.5 * root.s
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
