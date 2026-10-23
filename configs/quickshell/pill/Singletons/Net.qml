pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

/**
 * Wifi and bluetooth state read once for every pill and surface.
 */
Singleton {
    readonly property var wifiDev: Networking.devices.values.find(d => d && d.type === DeviceType.Wifi) || null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(n => n && n.connected) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleBt() {
        if (btAdapter)
            btAdapter.enabled = !btAdapter.enabled;
    }
}
