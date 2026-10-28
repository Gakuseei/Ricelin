pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live weather from Open-Meteo with no API key, located once via ip-api or `Flags.weatherCity` and cached, then refreshed every 20 minutes and retried sooner after a failure.
 */
Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin"

    property int codeNow: 0
    property int humidity: 0
    property bool isDay: true
    property string city: ""
    property bool ready: false
    /** Epoch ms of the last successful forecast fetch, 0 before the first. */
    property real updatedAt: 0

    /** Fetched temperatures stay in Celsius so a unit switch converts at once without a refetch. */
    property real rawNow: 0
    property var rawHourly: []
    property var rawDaily: []

    readonly property bool fahrenheit: Flags.weatherUnit === "f"
    readonly property int tempNow: temp(rawNow)
    readonly property var hourly: rawHourly.map(r => ({ hour: r.hour, temp: root.temp(r.t), code: r.code }))
    readonly property var daily: rawDaily.map(r => ({
        day: Clock.weekday(r.date, Flags.dateLang),
        date: r.date,
        code: r.code,
        temp: root.temp(r.t),
        rh: r.rh
    }))

    /** A Celsius reading as a whole number in the chosen unit. */
    function temp(c) {
        return Math.round(fahrenheit ? c * 9 / 5 + 32 : c);
    }

    /** Retry delays after a failed lookup or fetch; past the last one the 20 minute cycle takes over. */
    readonly property var backoff: [20000, 60000, 180000]
    property int failures: 0

    function failed() {
        if (retry.running || failures >= backoff.length)
            return;
        retry.interval = backoff[failures];
        failures++;
        retry.restart();
    }

    function succeeded() {
        failures = 0;
        retry.stop();
    }

    /** Next step of the chain: a fetch once located, else the location lookup again. */
    function refresh() {
        if (located)
            fetchWeather();
        else
            locate();
    }

    property real lat: 0
    property real lon: 0
    property bool located: false

    /**
     * Maps a WMO weather code to a glyph name, with clear skies switching to moon at night.
     */
    function glyphFor(code, day) {
        if (code === 0)
            return day ? "sun" : "moon";
        if (code <= 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "cloud-fog";
        if (code >= 95)
            return "cloud-lightning";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "cloud-snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "cloud-rain";
        return "cloud";
    }

    /** Short english word for a WMO weather code, for labels and accessibility. */
    function labelFor(code) {
        if (code === 0)
            return "Clear";
        if (code <= 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 95)
            return "Thunder";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "Snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "Rain";
        return "Cloudy";
    }

    /** Persist resolved coordinates so a restart skips the location round-trip. */
    function writeLoc() {
        locCache.setText(JSON.stringify({ city: root.city, lat: root.lat, lon: root.lon }));
    }

    function fetchWeather() {
        if (!located || wxProc.running)
            return;
        wxProc.running = true;
    }

    /**
     * Loads cached coordinates synchronously (blockLoading), and a missing or bad cache falls back to a fresh location lookup.
     */
    Component.onCompleted: {
        try {
            var c = JSON.parse(locCache.text());
            if (c && typeof c.lat === "number" && typeof c.lon === "number") {
                root.city = c.city || "";
                root.lat = c.lat;
                root.lon = c.lon;
                root.located = true;
                root.fetchWeather();
                return;
            }
        } catch (e) {}
        root.locate();
    }

    FileView {
        id: locCache
        path: root.cacheDir + "/weather-loc.json"
        blockLoading: true
        printErrors: false
    }

    /** Resolve coordinates: geocode the manual city override, else fall back to IP. */
    function locate() {
        if (ipProc.running || geoProc.running)
            return;
        if (Flags.weatherCity && Flags.weatherCity.trim().length > 0)
            geoProc.running = true;
        else
            ipProc.running = true;
    }

    Connections {
        target: Flags
        function onWeatherCityChanged() { root.locate(); }
    }

    Process {
        id: ipProc
        command: ["curl", "-s", "--max-time", "8", "http://ip-api.com/json?fields=lat,lon,city"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    if (typeof d.lat === "number" && typeof d.lon === "number") {
                        root.city = d.city || "";
                        root.lat = d.lat;
                        root.lon = d.lon;
                        root.located = true;
                        root.writeLoc();
                        root.fetchWeather();
                        return;
                    }
                } catch (e) {}
                root.failed();
            }
        }
    }

    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "8", "-G",
            "https://geocoding-api.open-meteo.com/v1/search",
            "--data-urlencode", "name=" + (Flags.weatherCity || ""),
            "--data-urlencode", "count=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    var r = d.results && d.results[0];
                    if (r && typeof r.latitude === "number" && typeof r.longitude === "number") {
                        root.city = r.name || "";
                        root.lat = r.latitude;
                        root.lon = r.longitude;
                        root.located = true;
                        root.writeLoc();
                        root.fetchWeather();
                        return;
                    }
                } catch (e) {}
                root.failed();
            }
        }
    }

    Process {
        id: wxProc
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat
            + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m"
            + "&hourly=temperature_2m,weather_code&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,relative_humidity_2m_mean&forecast_days=5&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    var cur = d.current;
                    if (!cur || typeof cur.temperature_2m !== "number") {
                        root.failed();
                        return;
                    }
                    var rows = [];
                    var h = d.hourly;
                    if (h && h.time && h.temperature_2m && h.weather_code) {
                        var n = Math.min(h.time.length, h.temperature_2m.length, h.weather_code.length);
                        for (var i = 0; i < n; i++) {
                            rows.push({
                                hour: h.time[i].slice(11, 13),
                                t: h.temperature_2m[i],
                                code: h.weather_code[i]
                            });
                        }
                    }
                    var days = [];
                    var dd = d.daily;
                    if (dd && dd.time && dd.weather_code && dd.temperature_2m_max && dd.relative_humidity_2m_mean) {
                        var m = Math.min(dd.time.length, dd.weather_code.length, dd.temperature_2m_max.length, dd.relative_humidity_2m_mean.length);
                        for (var j = 0; j < m; j++) {
                            var p = dd.time[j].split("-");
                            days.push({
                                date: new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])),
                                code: dd.weather_code[j],
                                t: dd.temperature_2m_max[j],
                                rh: Math.round(dd.relative_humidity_2m_mean[j])
                            });
                        }
                    }
                    root.rawNow = cur.temperature_2m;
                    root.codeNow = cur.weather_code;
                    root.humidity = Math.round(cur.relative_humidity_2m);
                    root.isDay = cur.is_day === 1;
                    root.rawHourly = rows;
                    root.rawDaily = days;
                    root.ready = true;
                    root.updatedAt = Date.now();
                    root.succeeded();
                } catch (e) {
                    root.failed();
                }
            }
        }
    }

    Timer {
        id: retry
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1200000
        running: true
        repeat: true
        onTriggered: {
            root.failures = 0;
            root.refresh();
        }
    }
}
