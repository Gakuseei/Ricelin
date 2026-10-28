import QtQuick
import "../Singletons"
import "app.js" as App

AppPage {
    id: page
    pageId: "weather"

    property string looking: ""
    property string missed: ""
    property bool refreshing: false

    readonly property string lastText: Qt.formatTime(new Date(Weather.updatedAt), Flags.time12h ? "h:mm AP" : "HH:mm")

    readonly property string placeLine: looking.length > 0 ? "Looking up “" + looking + "”…"
        : missed.length > 0 ? "Couldn't look up “" + missed + "” yet" + (Weather.city.length > 0 ? ", still showing " + Weather.city : ", trying again")
        : Weather.city.length > 0 ? (Flags.weatherCity.trim().length > 0 ? "Showing " + Weather.city : "Showing " + Weather.city + ", found from your connection")
        : "Leave empty to find your town automatically"

    readonly property string statusLine: refreshing ? "Refreshing…"
        : Weather.updatedAt > 0 ? "Updated at " + lastText
        : Weather.ready ? "Up to date"
        : "Waiting for the first forecast"

    function setCity(text) {
        const t = text.trim();
        if (t === Flags.weatherCity)
            return;
        missed = "";
        looking = t.length > 0 ? t : "your location";
        lookGuard.restart();
        Flags.weatherCity = t;
    }

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        refreshGuard.restart();
        Weather.refresh();
    }

    function reset() {
        if (Flags.weatherCity.length > 0) {
            missed = "";
            looking = "your location";
            lookGuard.restart();
        }
        Flags.weatherCity = "";
        Flags.weatherUnit = "c";
    }

    function located() {
        looking = "";
        missed = "";
        lookGuard.stop();
    }

    Connections {
        target: Weather
        function onLatChanged() { page.located(); }
        function onLonChanged() { page.located(); }
        function onCityChanged() { page.located(); }
        function onUpdatedAtChanged() {
            page.located();
            if (page.refreshing) {
                page.refreshing = false;
                refreshGuard.stop();
                App.toast("Weather updated");
            }
        }
        function onFailuresChanged() {
            if (Weather.failures === 0)
                return;
            if (page.looking.length > 0) {
                page.missed = page.looking;
                page.looking = "";
            }
            if (page.refreshing) {
                page.refreshing = false;
                refreshGuard.stop();
                App.toast("Couldn't reach the weather service", "error");
            }
        }
    }

    /** A refresh that never answers (lookup already busy, retries used up) stops spinning after a while. */
    Timer {
        id: refreshGuard
        interval: 25000
        onTriggered: {
            page.refreshing = false;
            App.toast("No answer from the weather service yet", "error");
        }
    }

    Timer {
        id: lookGuard
        interval: 25000
        onTriggered: {
            if (page.looking.length > 0) {
                page.missed = page.looking;
                page.looking = "";
            }
        }
    }

    AppGroup {
        title: "Location and units"

        AppRow {
            label: "Town"
            sub: page.placeLine
            key: "weather.city"
            AppField {
                fieldWidth: 230
                text: Flags.weatherCity
                placeholder: "Automatic from your location"
                onAccepted: (t) => page.setCity(t)
            }
        }
        AppRow {
            label: "Unit"
            sub: "Temperature in the pill and calendar" + (Weather.ready ? ", now " + Weather.tempNow + "°" : "")
            key: "weather.unit"
            AppSeg {
                options: [{ label: "°C", value: "c" }, { label: "°F", value: "f" }]
                value: Flags.weatherUnit
                onPicked: (v) => Flags.weatherUnit = v
            }
        }
    }

    AppGroup {
        title: "Forecast"

        AppRow {
            label: page.statusLine
            sub: "From Open-Meteo, no account needed. Refreshes every 20 minutes."
            key: "weather.refresh"
            AppButton {
                text: page.refreshing ? "Refreshing…" : "Refresh now"
                enabled: !page.refreshing
                onClicked: page.refresh()
            }
        }
    }
}
