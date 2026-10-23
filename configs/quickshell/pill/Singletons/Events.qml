pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Local calendar events in ~/.local/state/ricelin/events.json, read only at startup because watching our own writes raced FileView and dropped new events.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin"

    property var events: []
    property int nextId: 1

    /**
     * Birthday-looking titles in the languages Erik's contacts use, so new entries can suggest yearly and old ones get classified on load.
     */
    readonly property var birthdayRe: /geburtstag|geb\.|birthday|b-?day|🎂|cumplea|anniversaire|compleanno|anivers|verjaardag|рожд|誕生|생일|urodziny|do[ğg]um/i

    function isBirthday(t) {
        return root.birthdayRe.test(t || "");
    }

    /**
     * Advances nextId past every loaded id (Date.now() and Math.random() throw in this engine) and writes back old entries healed with a recur field.
     */
    function reloadEvents() {
        var arr = [];
        try {
            var t = file.text();
            if (t && t.trim().length > 0) {
                var parsed = JSON.parse(t);
                if (Array.isArray(parsed))
                    arr = parsed;
            }
        } catch (e) {
            arr = [];
        }
        var maxId = 0;
        var healed = false;
        for (var i = 0; i < arr.length; i++) {
            var n = Number(arr[i].id);
            if (n > maxId)
                maxId = n;
            var e = arr[i];
            if (e.recur === undefined) {
                e.recur = e.yearly === true ? "year" : (root.isBirthday(e.text) ? "year" : "");
                delete e.yearly;
                healed = true;
            }
        }
        root.nextId = maxId + 1;
        root.events = arr;
        if (healed)
            root.persist();
    }

    function persist() {
        file.setText(JSON.stringify(root.events));
    }

    /** Last day an event covers: its endDate, or its start when single-day. */
    function lastDay(e) {
        return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
    }

    function covers(e, dateStr) {
        if (e.recur === "year")
            return dateStr.slice(5) === e.date.slice(5);
        if (e.recur === "month")
            return dateStr.slice(8) === e.date.slice(8);
        return dateStr >= e.date && dateStr <= root.lastDay(e);
    }

    /** Events covering `dateStr`, sorted by start time; an empty time sorts first. */
    function forDate(dateStr) {
        var out = root.events.filter(function (e) { return root.covers(e, dateStr); });
        out.sort(function (a, b) {
            var at = a.time || "";
            var bt = b.time || "";
            if (at === bt)
                return 0;
            if (at === "")
                return -1;
            if (bt === "")
                return 1;
            return at < bt ? -1 : 1;
        });
        return out;
    }

    function hasEvents(dateStr) {
        for (var i = 0; i < root.events.length; i++) {
            if (root.covers(root.events[i], dateStr))
                return true;
        }
        return false;
    }

    /** Append an event and persist; reassigns `events` so bindings refresh. */
    function add(dateStr, endDate, time, endTime, text, recur) {
        var next = root.events.slice();
        next.push({
            id: root.nextId,
            date: dateStr,
            endDate: endDate || "",
            time: time || "",
            endTime: endTime || "",
            text: text || "",
            recur: recur || ""
        });
        root.nextId += 1;
        root.events = next;
        root.persist();
    }

    function remove(id) {
        root.events = root.events.filter(function (e) { return e.id !== id; });
        root.persist();
    }

    Component.onCompleted: reloadEvents()

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: true
        printErrors: false

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                file.setText("[]");
        }
    }
}
