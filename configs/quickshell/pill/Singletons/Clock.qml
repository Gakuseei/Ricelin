pragma Singleton
import QtQuick
import Quickshell

/**
 * One wall clock for every pill, formatted the way the clock settings ask.
 */
Singleton {
    id: root

    readonly property var now: sys.date
    readonly property string timeFormat: (Flags.time12h ? "h:mm" : "HH:mm")
        + (Flags.clockSeconds ? ":ss" : "")
        + (Flags.time12h ? " AP" : "")
    readonly property string hhmm: now ? Qt.formatTime(now, timeFormat) : ""
    readonly property var locale: Qt.locale(localeName(Flags.dateLang))
    readonly property string date: now ? dateFor(Flags.dateStyle, Flags.dateLang, now) : ""

    function localeName(lang) {
        return lang === "de" ? "de_DE" : "en_US";
    }

    /** Short weekday name ("Mon", "Mo") for a Date or a weekday number 0-6 from Sunday. */
    function weekday(when, lang) {
        const dow = typeof when === "number" ? when : when.getDay();
        return Qt.locale(localeName(lang)).dayName(dow, Locale.ShortFormat).replace(/\.$/, "");
    }

    /**
     * Formats `when` (default: now) in a date preset; German drops the abbreviation dots ("Mo 27", "27. Okt") and unknown styles go to Qt as a format string.
     */
    function dateFor(style, lang, when) {
        const d = when || root.now || new Date();
        const loc = Qt.locale(localeName(lang));
        const de = lang === "de";
        const day = d.getDate();
        const dayNum = de ? day + "." : String(day);
        const mon = loc.monthName(d.getMonth(), Locale.ShortFormat).replace(/\.$/, "");
        switch (style) {
        case "ddd d":
            return weekday(d, lang) + " " + day;
        case "d MMM":
            return dayNum + " " + mon;
        case "ddd d MMM":
            return weekday(d, lang) + " " + dayNum + " " + mon;
        case "dd.MM.":
            return String(day).padStart(2, "0") + "." + String(d.getMonth() + 1).padStart(2, "0") + ".";
        default:
            return loc.toString(d, style || "ddd d MMM");
        }
    }

    SystemClock {
        id: sys
        precision: Flags.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
