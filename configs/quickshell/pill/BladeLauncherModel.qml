pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons" as S

QtObject {
    id: root

    /*
     * Unified Blade application model.
     *
     * Ricelin applications come from two places:
     *
     *   1. AppRegistry
     *      - Wine
     *      - Wine-Staging
     *      - UMU / Proton
     *      - Steam
     *      - explicitly configured applications
     *
     *   2. DesktopEntries
     *      - native Linux applications
     *
     * Native desktop entries are launched through their real DesktopEntry
     * object. They are never reconstructed from Exec=, because Exec= may
     * contain quoting, placeholders (%U/%F/%u/%f), env assignments,
     * Flatpak commands, etc.
     *
     * The model is intentionally self-updating: no application IDs are
     * hard-coded here.
     */

    readonly property int maxVisible: 6

    function categoryForDesktop(entry) {
        if (!entry)
            return "utility"

        var cats = String((entry.categories || []).join(",")).toLowerCase()

        if (cats.indexOf("game") >= 0)
            return "game"

        if (cats.indexOf("development") >= 0)
            return "development"

        if (cats.indexOf("science") >= 0 ||
            cats.indexOf("engineering") >= 0)
            return "engineering"

        return "utility"
    }

    function desktopForRegistryApp(app) {
        if (!app || app.runner !== "native")
            return null

        var apps = DesktopEntries.applications.values || []

        /*
         * Prefer exact desktop-entry ID, then fall back to the
         * application name. This also handles the native records that
         * were previously imported into applications.json without a
         * separate desktopEntryId field.
         */
        for (var i = 0; i < apps.length; ++i) {
            var e = apps[i]
            if (!e || e.noDisplay)
                continue

            if (e.id && app.id && String(e.id) === String(app.id))
                return e
        }

        for (var j = 0; j < apps.length; ++j) {
            var e2 = apps[j]
            if (!e2 || e2.noDisplay)
                continue

            if (e2.name &&
                app.name &&
                String(e2.name).toLowerCase() === String(app.name).toLowerCase())
                return e2
        }

        return null
    }

    readonly property var unifiedApps: {
        var registry = S.AppRegistry.apps || []
        var desktops = DesktopEntries.applications.values || []
        var out = []

        /*
         * Registry is authoritative for non-native applications.
         *
         * Native registry records are retained only when their actual
         * DesktopEntry can be resolved, because DesktopEntry.execute()
         * is the safe/complete way to honor Linux desktop Exec semantics.
         */
        for (var i = 0; i < registry.length; ++i) {
            var app = registry[i]
            if (!app)
                continue

            if (app.runner === "native") {
                var desktop = root.desktopForRegistryApp(app)

                if (!desktop)
                    continue

                out.push(Object.assign({}, app, {
                    nativeDesktop: true,
                    desktopEntry: desktop
                }))
            } else {
                out.push(app)
            }
        }

        /*
         * Add live native desktop applications that are not already
         * represented in AppRegistry.
         *
         * These are ephemeral Blade entries. They do not pollute the
         * persistent Ricelin registry merely by being installed on the
         * system.
         */
        for (var d = 0; d < desktops.length; ++d) {
            var e = desktops[d]

            if (!e || e.noDisplay || !e.name)
                continue

            var alreadyRepresented = false

            for (var r = 0; r < registry.length; ++r) {
                var ra = registry[r]

                if (!ra || ra.runner !== "native")
                    continue

                if (e.id &&
                    ra.id &&
                    String(e.id) === String(ra.id)) {
                    alreadyRepresented = true
                    break
                }

                if (e.name &&
                    ra.name &&
                    String(e.name).toLowerCase() === String(ra.name).toLowerCase()) {
                    alreadyRepresented = true
                    break
                }
            }

            if (alreadyRepresented)
                continue

            /*
             * Steam desktop entries should not become duplicate native
             * Blade entries when their Steam app is already represented by
             * the registry. The existing scanner already knows how to
             * identify Steam URLs, so this lightweight filter handles the
             * common case here too.
             */
            var execString = String(e.execString || "")

            if (execString.indexOf("steam://rungameid/") >= 0)
                continue

            var desktopId = e.id
                ? String(e.id)
                : ("name-" + String(e.name).toLowerCase().replace(/[^a-z0-9]+/g, "-"))

            out.push({
                id: "desktop:" + desktopId,
                name: String(e.name),
                category: root.categoryForDesktop(e),
                favorite: false,
                iconImage: "",
                runner: "native",
                executable: "",
                workingDirectory: "",
                prefix: "",
                umuId: "",
                steamAppId: "",
                protonBuild: "",
                graphicsApi: "native",
                args: [],
                env: {},
                dllOverrides: {},
                window: {
                    mode: "windowed",
                    monitor: "",
                    resolution: "native"
                },
                performance: {
                    mangohud: false,
                    gamescope: false,
                    fpsLimit: 0
                },
                createdAt: 0,
                lastLaunched: 0,
                launchCount: 0,
                nativeDesktop: true,
                desktopEntry: e
            })
        }

        /*
         * Priority:
         *
         *   favorite
         *   ↓
         *   games
         *   ↓
         *   configured non-native applications
         *   ↓
         *   recently launched
         *   ↓
         *   alphabetical
         *
         * This keeps Blades game-centric without making development and
         * utility applications impossible to surface: favoriting one moves
         * it above the normal game/non-game ordering.
         */
        out.sort(function(a, b) {
            var af = a.favorite ? 1 : 0
            var bf = b.favorite ? 1 : 0
            if (af !== bf)
                return bf - af

            var ag = a.category === "game" ? 1 : 0
            var bg = b.category === "game" ? 1 : 0
            if (ag !== bg)
                return bg - ag

            var ar = a.runner !== "native" ? 1 : 0
            var br = b.runner !== "native" ? 1 : 0
            if (ar !== br)
                return br - ar

            var at = Number(a.lastLaunched || 0)
            var bt = Number(b.lastLaunched || 0)
            if (at !== bt)
                return bt - at

            var an = String(a.name || "").toLowerCase()
            var bn = String(b.name || "").toLowerCase()

            if (an < bn)
                return -1
            if (an > bn)
                return 1
            return 0
        })

        return out
    }

    readonly property var selectedIds: {
        var result = []

        for (var i = 0; i < root.unifiedApps.length; ++i) {
            var app = root.unifiedApps[i]

            if (!app)
                continue

            // Cyberpunk 2077 is no longer installed locally; only its
            // old registry record remains. Keep the registry untouched,
            // but do not expose that stale record as a blade.
            var appId = String(app.id || "").toLowerCase()
            var appName = String(app.name || "").toLowerCase()

            // Do not expose stale/non-game launcher records as blades.
            // Cyberpunk 2077 is no longer installed locally. Steam and
            // Lutris are launchers, not games.
            if (
                appId === "cyberpunk2077" ||
                appId === "steam" ||
                appId === "lutris" ||
                appId === "desktop:steam" ||
                appId.indexOf("desktop:net.lutris.") === 0 ||
                appName === "steam" ||
                appName === "lutris"
            )
                continue

            var runner = String(app.runner || "").toLowerCase()
            var isGame = String(app.category || "").toLowerCase() === "game"
            var isWineApp =
                runner === "wine" ||
                runner === "wine-staging" ||
                runner === "umu"

            if (isGame || isWineApp)
                result.push(app.id)
        }

        return result
    }

    property var launchingIds: ({})
    property string launchingAppId: ""

    property Timer launchFeedbackTimer: Timer {
        interval: 1800
        repeat: false

        onTriggered: {
            if (root.launchingAppId.length > 0)
                root.setLaunching(root.launchingAppId, false)

            root.launchingAppId = ""
        }
    }

    function appAt(index) {
        if (index < 0 || index >= root.selectedIds.length)
            return null

        var wantedId = root.selectedIds[index]

        for (var i = 0; i < root.unifiedApps.length; ++i) {
            var app = root.unifiedApps[i]

            if (app && String(app.id) === String(wantedId))
                return app
        }

        return null
    }

    readonly property int count: Math.min(
        root.selectedIds.length,
        root.maxVisible
    )

    function resolvedApps() {
        var result = []

        for (var i = 0; i < root.count; ++i) {
            var app = root.appAt(i)

            if (app)
                result.push(app)
        }

        return result
    }

    function isLaunching(index) {
        var app = root.appAt(index)

        if (!app)
            return false

        return !!root.launchingIds[app.id]
    }

    function setLaunching(appId, value) {
        var next = Object.assign({}, root.launchingIds)

        if (value)
            next[appId] = true
        else
            delete next[appId]

        root.launchingIds = next
    }

    function launch(index) {
        var app = root.appAt(index)

        if (!app)
            return

        if (root.launchingAppId.length > 0)
            root.setLaunching(root.launchingAppId, false)

        root.launchingAppId = app.id
        root.setLaunching(app.id, true)

        /*
         * Native Linux application:
         *
         * Use the desktop entry itself. This correctly handles:
         *   - %u / %U / %f / %F
         *   - quoted Exec arguments
         *   - env assignments
         *   - Flatpak launchers
         *   - Wine-generated desktop entries
         *   - application-specific desktop integration
         */
        if (app.nativeDesktop && app.desktopEntry) {
            app.desktopEntry.execute()

            /*
             * Synthetic native desktop entries do not live in the
             * registry, so there is nothing to persist for them.
             *
             * Native registry records do get their launch statistics
             * updated normally.
             */
            if (S.AppRegistry.byId(app.id))
                S.AppRegistry.recordLaunch(app.id)

            root.launchFeedbackTimer.restart()
            return
        }

        /*
         * Everything that needs a compatibility/runtime decision stays
         * behind AppLauncher.
         */
        S.AppLauncher.launch(app.id, false)
        root.launchFeedbackTimer.restart()
    }

    function launchAppId(id) {
        for (var i = 0; i < root.selectedIds.length; ++i) {
            if (String(root.selectedIds[i]) === String(id)) {
                root.launch(i)
                return
            }
        }

        console.warn("BladeLauncher: app ID not available in Games+Wine selection:", id)
    }

    function isRunning(index) {
        var app = root.appAt(index)

        if (!app || app.nativeDesktop)
            return false

        return S.AppLauncher.isRunning(app.id)
    }

    function toggle(index) {
        root.launch(index)
    }
}
