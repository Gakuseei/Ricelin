pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * A pill row built from module ids: `div` splits groups at the wide gap with a hairline, modules inside a group sit at the cluster gap.
 */
Item {
    id: strip

    property var ids: []
    property string phase: "rest"
    property Item host: null
    property real s: 1
    property string screenName: ""
    property var barWindow: null

    /**
     * `live` turns pointer input on; `actions` false keeps hover tints but fires nothing, as in the settings preview.
     */
    property bool live: true
    property bool actions: true

    /**
     * False while the row sits hidden at zero opacity, so looping content can rest.
     */
    property bool awake: true

    /** A preset thumbnail's own glyph look; null and empty follow the flags. */
    property var glyphsOn: null
    property string glyphText: ""

    readonly property bool hover: phase === "hover"
    readonly property real groupGap: (hover ? 20 : 9) * s
    readonly property real clusterGap: (hover ? 12 : 9) * s
    readonly property real divH: (hover ? 22 : 14) * s

    /**
     * The glyph outline at rest fades into Ame as the hover soul arrives and flashes once when it does.
     */
    readonly property real glyphOutline: host && !hover
        ? Math.min(1, (host.mode === "rest" || !host.hoverSoulGate ? 0.5 : 0) + host.kanjiFlash)
        : 0.5

    property Item wsItem: null
    property Item glyphItem: null

    /**
     * Keyed on the serialized list so a flags reload with the same modules never rebuilds the row.
     */
    readonly property string key: JSON.stringify(ids || [])
    readonly property var segs: {
        const out = [];
        const list = JSON.parse(key);
        if (!Array.isArray(list))
            return out;
        let cur = null;
        for (const id of list) {
            if (id === "div") {
                if (out.length > 0 && out[out.length - 1].div)
                    continue;
                out.push({ div: true, ids: [] });
                cur = null;
            } else {
                if (!cur) {
                    cur = { div: false, ids: [] };
                    out.push(cur);
                }
                cur.ids.push(String(id));
            }
        }
        return out;
    }

    property var fills: []

    function setFill(i, v) {
        if (fills[i] === v)
            return;
        const f = fills.slice();
        f[i] = v;
        fills = f;
    }

    /**
     * A divider shows right after a filled group and only when another filled group follows.
     */
    function divShown(i) {
        const f = fills;
        if (i < 1 || f[i - 1] !== true)
            return false;
        for (let j = i + 1; j < segs.length; j++)
            if (f[j] === true)
                return true;
        return false;
    }

    function open(name) {
        if (actions && host && name)
            host.requestSurface(name);
    }

    /**
     * LiveActivity walks up to the first `requestSurface`, which lands here so the preview stays inert.
     */
    function requestSurface(name) {
        open(name);
    }

    function soul(item) {
        if (host && hover)
            host.soulItem = item;
    }

    function wsHover(index) {
        if (host && hover && index >= 0) {
            host.soulItem = null;
            host.soulWsIndex = index;
        }
    }

    /**
     * Runs the `Flags.hoverActions` entry for this icon and button, else the built-in.
     */
    function press(id, button, surface, builtin) {
        if (!actions)
            return;
        const o = Flags.hoverActions ? Flags.hoverActions[id] : undefined;
        const a = o ? o[button] : undefined;
        if (typeof a !== "string" || a.length === 0) {
            builtin();
            return;
        }
        if (a === "open")
            open(surface);
        else if (a === "toggle-wifi")
            Net.toggleWifi();
        else if (a === "toggle-bt")
            Net.toggleBt();
        else if (a === "toggle-dnd")
            Flags.dnd = !Flags.dnd;
        else if (a === "toggle-game")
            Flags.gameMode = !Flags.gameMode;
        else if (a === "stop-recording") {
            if (ScreenRec.recording)
                ScreenRec.stop();
        } else if (a.indexOf("cmd:") === 0 && a.length > 4)
            Quickshell.execDetached(["sh", "-c", a.slice(4)]);
    }

    implicitWidth: outer.implicitWidth
    implicitHeight: outer.implicitHeight

    PillModules {
        id: mods
        row: strip
    }

    Row {
        id: outer
        anchors.centerIn: parent
        spacing: strip.groupGap

        Repeater {
            model: strip.segs

            delegate: Item {
                id: seg

                required property var modelData
                required property int index
                readonly property bool isDiv: modelData.div === true
                readonly property bool filled: !isDiv && inner.implicitWidth > 0

                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                visible: isDiv ? strip.divShown(index) : filled
                implicitWidth: isDiv ? 1 : inner.implicitWidth
                implicitHeight: isDiv ? strip.divH : inner.implicitHeight

                onFilledChanged: strip.setFill(index, filled)
                Component.onCompleted: strip.setFill(index, filled)

                Rectangle {
                    visible: seg.isDiv
                    anchors.fill: parent
                    color: Theme.hair
                }

                Row {
                    id: inner
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: strip.clusterGap

                    Repeater {
                        model: seg.modelData.ids

                        delegate: Loader {
                            required property string modelData
                            required property int index

                            /** The group's last module, so a trailing hairline inside it can drop. */
                            readonly property bool tail: index === seg.modelData.ids.length - 1

                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            sourceComponent: mods.byId[modelData] || null
                            visible: item !== null && item.shown !== false
                        }
                    }
                }
            }
        }
    }
}
