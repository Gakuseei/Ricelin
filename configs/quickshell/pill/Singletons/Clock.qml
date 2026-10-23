pragma Singleton
import QtQuick
import Quickshell

/**
 * One wall clock for every pill, formatted the way the Look settings ask.
 */
Singleton {
    readonly property var now: sys.date
    readonly property string timeFormat: (Flags.time12h ? "h:mm" : "HH:mm")
        + (Flags.clockSeconds ? ":ss" : "")
        + (Flags.time12h ? " AP" : "")
    readonly property string hhmm: now ? Qt.formatTime(now, timeFormat) : ""
    readonly property string date: now ? Qt.locale("en_US").toString(now, "ddd d MMM") : ""

    SystemClock {
        id: sys
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
