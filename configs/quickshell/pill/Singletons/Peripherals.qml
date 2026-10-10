pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower

/**
 * Battery state for peripherals: every UPower device that is not the laptop
 * battery or line power (controller over Bluetooth, mouse over a Lightspeed
 * dongle, headset). BlueZ only publishes Battery1 with Experimental on, so the
 * Bluetooth surface reads percentages from here instead. A device whose
 * nativePath carries a MAC is keyed by it so a Bluetooth row can look up its
 * own battery; the rest are USB-dongle peripherals the surface lists on their
 * own. `connectedCount` tracks connected Bluetooth devices reactively through
 * an Instantiator, since a plain binding on the device list misses per-device
 * connected flips. A peripheral at or below 20% raises one notify-send, reset
 * once it climbs back or disappears.
 */
Singleton {
    id: root

    readonly property int lowAt: 20
    readonly property var devices: (typeof UPower !== "undefined" && UPower && UPower.devices) ? UPower.devices.values : []

    readonly property var list: devices.filter(function(d) {
        return d && d.ready && d.isPresent && !d.isLaptopBattery
            && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery
            && d.type !== UPowerDeviceType.Unknown;
    })

    readonly property var byMac: {
        var m = {};
        for (var i = 0; i < list.length; i++) {
            var mac = macOf(list[i]);
            if (mac.length)
                m[mac] = list[i];
        }
        return m;
    }

    readonly property var usb: list.filter(function(d) { return macOf(d).length === 0; })

    property int connectedCount: 0
    property int lowestPct: -1
    property var notified: ({})

    function macOf(d) {
        var m = String((d && d.nativePath) || "").match(/([0-9a-f]{2}[:_]){5}[0-9a-f]{2}/i);
        return m ? m[0].replace(/_/g, ":").toUpperCase() : "";
    }

    function pct(d) {
        return d ? Math.round(Math.max(0, Math.min(1, d.percentage)) * 100) : -1;
    }

    function charging(d) {
        return d ? (d.state === UPowerDeviceState.Charging || d.state === UPowerDeviceState.FullyCharged) : false;
    }

    function glyphFor(d) {
        switch (d ? d.type : -1) {
        case UPowerDeviceType.Mouse: case UPowerDeviceType.Touchpad: return "mouse";
        case UPowerDeviceType.Keyboard: return "keyboard";
        case UPowerDeviceType.GamingInput: case UPowerDeviceType.RemoteControl: return "gamepad";
        case UPowerDeviceType.Headset: case UPowerDeviceType.Headphones:
        case UPowerDeviceType.Speakers: case UPowerDeviceType.OtherAudio: return "speaker";
        case UPowerDeviceType.MediaPlayer: return "music";
        case UPowerDeviceType.Monitor: case UPowerDeviceType.Computer: return "monitor";
        }
        return "bluetooth";
    }

    function refresh() {
        var lowest = -1;
        var seen = {};
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            var p = pct(d);
            var key = d.nativePath;
            seen[key] = true;
            if (lowest < 0 || p < lowest)
                lowest = p;
            if (p <= lowAt && !charging(d)) {
                if (!notified[key]) {
                    notified[key] = true;
                    notifyProc.command = ["notify-send", "-a", "Ricelin", "-i", "battery-caution",
                        (d.model || "Device") + " at " + p + "%", "Charge it soon"];
                    notifyProc.running = true;
                }
            } else {
                delete notified[key];
            }
        }
        for (var k in notified)
            if (!seen[k]) delete notified[k];
        lowestPct = lowest;
    }

    function recount() {
        var n = 0;
        var devs = (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i] && devs[i].connected) n++;
        connectedCount = n;
    }

    onListChanged: refresh()

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Instantiator {
        model: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.devices : null
        onObjectAdded: root.recount()
        onObjectRemoved: root.recount()
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root.recount() }
        }
    }

    Process {
        id: notifyProc
    }
}
