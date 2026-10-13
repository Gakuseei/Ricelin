pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import "Singletons"

/**
 * The dock window: a click-through strip down the right edge (or the left, see
 * Dock.side) of one screen with
 * the glass capsule (DockBody) floating in it. It lives on the Top layer, so a
 * fullscreen window covers it, and only the capsule takes input. The blur behind
 * the glass comes from the `ricelin-glass` layer rule (namespace ricelin-dock).
 *
 * This file owns what needs Quickshell: the window, its exclusive zone, and the
 * live Wi-Fi and Bluetooth state handed to the body.
 */
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1

    /** Asks the shell to toggle one of the pill's surfaces on this monitor. */
    signal surfaceRequested(string name)

    color: "transparent"
    visible: true
    focusable: false
    exclusionMode: Dock.reserve ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: Dock.reserve ? dock.edge + dock.bodyW + dock.edge / 2 : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ricelin-dock"

    anchors { left: !Dock.onRight; right: Dock.onRight; top: true; bottom: true }
    implicitWidth: dock.edge + dock.bodyW + dock.hintRoom

    mask: Region {
        x: dock.capsule.x
        y: dock.capsule.y
        width: dock.capsule.width
        height: dock.capsule.height
    }

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0
    readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false

    DockBody {
        id: dock
        anchors.fill: parent
        s: root.s
        screenName: root.modelData ? root.modelData.name : ""
        wifiPresent: root.wifiDev !== null
        wifiOn: root.wifiOn
        wifiLevel: root.wifiLevel
        wifiName: root.wifiActive ? (root.wifiActive.name || "Connected") : ""
        btPresent: root.btAdapter !== null
        btOn: root.btOn

        onSurfaceRequested: (name) => root.surfaceRequested(name)
        onWifiToggled: if (typeof Networking !== "undefined" && Networking) Networking.wifiEnabled = !Networking.wifiEnabled
        onBtToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
    }
}
