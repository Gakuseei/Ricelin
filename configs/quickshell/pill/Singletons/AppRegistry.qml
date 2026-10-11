pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Application Registry: the single source of truth for every non-native app
 * Ricelin knows how to launch — games today, dev/engineering/utility tools
 * later. The Games surface is a filtered *view* over this list, not a
 * subsystem of its own, so a new category never needs new plumbing.
 *
 * Each entry is a plain JSON object (see `template()` below for the full
 * shape); the registry itself is agnostic about what "runner" means, that
 * belongs to RuntimeManager and AppLauncher. Persisted as one JSON array —
 * same raw FileView + JSON.parse/stringify approach as Launcher's usage
 * store, chosen over JsonAdapter because JsonAdapter's typed schema doesn't
 * fit a free-form, growable list of heterogeneous app records.
 *
 * Writes are debounced through `persist()` and always replace `apps` with a
 * new array (never mutate in place) so every binding and Repeater downstream
 * re-evaluates reliably — QML's var properties don't notify on in-place
 * array/object mutation.
 */
Singleton {
    id: root

    property bool ready: false
    property var apps: []

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ricelin"
    readonly property string path: root.dir + "/applications.json"

    readonly property var categories: [
        { id: "game", label: "Games", glyph: "gamepad" },
        { id: "development", label: "Development", glyph: "keyboard" },
        { id: "engineering", label: "Engineering", glyph: "layers" },
        { id: "utility", label: "Utilities", glyph: "cog" }
    ]

    function categoryLabel(id) {
        for (var i = 0; i < root.categories.length; i++)
            if (root.categories[i].id === id)
                return root.categories[i].label;
        return id;
    }

    /** Every field an app record can carry. Spread this and override rather than hand-rolling a literal, so a later field addition only has to happen here. */
    function template() {
        return {
            id: "",
            name: "",
            category: "game",
            favorite: false,
            iconImage: "",
            runner: "wine",
            executable: "",
            workingDirectory: "",
            prefix: "",
            umuId: "",
            steamAppId: "",
            protonBuild: "GE-Proton",
            graphicsApi: "unknown",
            args: [],
            env: ({}),
            dllOverrides: ({}),
            window: { mode: "windowed", monitor: "", resolution: "native" },
            performance: { mangohud: false, gamescope: false, fpsLimit: 0 },
            createdAt: 0,
            lastLaunched: 0,
            launchCount: 0,
            runtime: { provider: "auto", variant: "", version: "", build: "" },
            environment: { type: "wineprefix", path: "", name: "", arch: "win64" }
        };
    }

    /**
     * `runner` and `prefix` are the actual source of truth — AppLauncher
     * only ever reads those two. `runtime` and `environment` below are
     * *derived* from them, one direction only, for a future richer display
     * (a name, an arch, a variant). They used to be independently settable
     * and reconciled by truthiness, which meant a stale `environment.path`
     * surviving an unrelated edit could silently overwrite a correct
     * `prefix` — not just duplicate data, an active corruption path. Making
     * the derivation one-way removes that failure mode structurally rather
     * than patching the specific case it was caught in.
     */
    function normalizeRecord(input) {
        var rec = Object.assign({}, root.template(), input || {});
        rec.window = Object.assign({}, root.template().window, input && input.window ? input.window : {});
        rec.performance = Object.assign({}, root.template().performance, input && input.performance ? input.performance : {});
        rec.env = Object.assign({}, input && input.env ? input.env : {});
        rec.dllOverrides = Object.assign({}, input && input.dllOverrides ? input.dllOverrides : {});
        rec.args = Array.isArray(input && input.args) ? input.args.slice() : [];

        var envInput = input && input.environment ? input.environment : {};
        rec.environment = {
            type: "wineprefix",
            path: rec.prefix || "",
            name: envInput.name || rec.name || "",
            arch: envInput.arch || "win64"
        };

        var rtInput = input && input.runtime ? input.runtime : {};
        rec.runtime = {
            provider: rec.runner || "native",
            variant: rtInput.variant || "",
            version: rtInput.version || "",
            build: rec.runner === "umu" ? (rec.protonBuild || "GE-Proton") : ""
        };

        return rec;
    }

    function runtimeFor(app) { return root.normalizeRecord(app).runtime; }
    function environmentFor(app) { return root.normalizeRecord(app).environment; }

    function byId(id) {
        for (var i = 0; i < root.apps.length; i++)
            if (root.apps[i].id === id)
                return root.apps[i];
        return null;
    }

    readonly property var byCategoryCache: {
        void root.apps;
        var out = {};
        for (var c = 0; c < root.categories.length; c++)
            out[root.categories[c].id] = [];
        for (var i = 0; i < root.apps.length; i++) {
            var a = root.apps[i];
            if (!out[a.category])
                out[a.category] = [];
            out[a.category].push(a);
        }
        for (var k in out) {
            out[k].sort((x, y) => {
                if (x.favorite !== y.favorite)
                    return x.favorite ? -1 : 1;
                return x.name.localeCompare(y.name);
            });
        }
        return out;
    }

    function appsFor(category) {
        return root.byCategoryCache[category] || [];
    }

    function countFor(category) {
        return root.appsFor(category).length;
    }

    function slugify(name) {
        var s = String(name).toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        return s.length > 0 ? s : "app";
    }

    function uniqueId(base) {
        var id = base, n = 2;
        while (root.byId(id) !== null) {
            id = base + "-" + n;
            n++;
        }
        return id;
    }

    /** Merges `partial` over template(), assigns a fresh unique id, appends and persists. Returns the stored record. */
    function add(partial) {
        var rec = root.normalizeRecord(partial || {});
        rec.id = root.uniqueId(root.slugify(rec.name || rec.executable || "app"));
        rec.createdAt = Date.now();
        root.apps = root.apps.concat([rec]);
        root.persist();
        return rec;
    }

    function update(id, patch) {
        root.apps = root.apps.map(a => a.id === id ? root.normalizeRecord(Object.assign({}, a, patch || {})) : a);
        root.persist();
    }

    function remove(id) {
        root.apps = root.apps.filter(a => a.id !== id);
        root.persist();
    }

    function toggleFavorite(id) {
        var a = root.byId(id);
        if (a)
            root.update(id, { favorite: !a.favorite });
    }

    function recordLaunch(id) {
        var a = root.byId(id);
        if (a)
            root.update(id, { lastLaunched: Date.now(), launchCount: (a.launchCount || 0) + 1 });
    }

    /** Seeds the three games carried over from the shell-function era, exactly as they were launched by hand, so the first run of the surface isn't empty. Only runs once, when the store is missing entirely. */
    function seedDefaults() {
        var home = Quickshell.env("HOME");
        root.apps = [
            root.normalizeRecord({
                id: "cyberpunk2077",
                name: "Cyberpunk 2077",
                category: "game",
                runner: "umu",
                executable: home + "/Games/Cyberpunk2077/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe",
                workingDirectory: home + "/Games/Cyberpunk2077/Cyberpunk 2077",
                prefix: home + "/Games/Cyberpunk2077/proton-prefix",
                umuId: "umu-cyberpunk2077",
                protonBuild: "GE-Proton",
                graphicsApi: "d3d12",
                runtime: { variant: "proton" },
                createdAt: Date.now()
            }),
            root.normalizeRecord({
                id: "undertale",
                name: "Undertale",
                category: "game",
                runner: "wine",
                executable: home + "/Games/Undertale/game/UNDERTALE.exe",
                workingDirectory: home + "/Games/Undertale/game",
                prefix: home + "/Games/Undertale/prefix",
                graphicsApi: "d3d9",
                runtime: { variant: "dxvk" },
                createdAt: Date.now()
            }),
            root.normalizeRecord({
                id: "hollowknight",
                name: "Hollow Knight",
                category: "game",
                runner: "wine",
                executable: home + "/Games/HollowKnight/game/hollow_knight.exe",
                workingDirectory: home + "/Games/HollowKnight/game",
                prefix: home + "/Games/HollowKnight/prefix",
                graphicsApi: "d3d11",
                runtime: { variant: "dxvk" },
                createdAt: Date.now()
            })
        ];
        root.persist();
    }

    function persist() {
        if (!root.ready)
            return;
        store.setText(JSON.stringify(root.apps, null, 2));
    }

    FileView {
        id: store
        path: root.path
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    /**
     * `~/.config/ricelin` may not exist yet on a fresh install, and setText()
     * needs it to already be there — so the very first load waits for this
     * mkdir to actually exit before touching the store, rather than firing
     * both in the same tick and racing it.
     */
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.dir]
        onExited: root.loadOrSeed()
    }

    function loadOrSeed() {
        var raw = "";
        try {
            raw = store.text();
        } catch (e) {
            raw = "";
        }
        if (raw && raw.length > 0) {
            try {
                root.apps = JSON.parse(raw).map(a => root.normalizeRecord(a));
                root.ready = true;
                return;
            } catch (e) {
                console.warn("AppRegistry: applications.json failed to parse, starting fresh:", e);
            }
        }
        root.ready = true;
        root.seedDefaults();
    }

    Component.onCompleted: mkdirProc.running = true
}
