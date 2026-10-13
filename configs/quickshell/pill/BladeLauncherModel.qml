pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"
import "lib/blades.js" as Blades

/**
 * What the blade fan shows: the games and Wine apps in the app registry.
 *
 * Which records qualify, and their order, is decided by lib/blades.js (games
 * and Wine-family runners by default, a per-app Auto / Pin / Hide override). No
 * app is named here, so a stale entry is hidden from the app's own editor
 * rather than by editing code. Installed desktop entries are not listed on
 * their own: add one through the Add or Scan sheet and it is a registry record
 * like any other.
 *
 * A native record whose desktop entry can be found is launched through that
 * entry, never rebuilt from Exec=, which may carry %u placeholders, env
 * assignments or Flatpak wrappers.
 */
QtObject {
    id: root

    readonly property int maxVisible: 6

    /** Id of the app that was just launched; shows as "starting" for a moment. */
    property string launchingId: ""

    function desktopFor(app) {
        if (!app || app.runner !== "native")
            return null;
        var entries = DesktopEntries.applications.values || [];
        for (var i = 0; i < entries.length; ++i) {
            var e = entries[i];
            if (e && !e.noDisplay && e.id && String(e.id) === String(app.id))
                return e;
        }
        var wanted = String(app.name || "").toLowerCase();
        for (var j = 0; j < entries.length; ++j) {
            var e2 = entries[j];
            if (e2 && !e2.noDisplay && wanted.length > 0 && String(e2.name || "").toLowerCase() === wanted)
                return e2;
        }
        return null;
    }

    /** Launchable records in blade order, capped at maxVisible. */
    readonly property var apps: {
        var picked = Blades.select(AppRegistry.apps, 0);
        var out = [];
        for (var i = 0; i < picked.length && out.length < root.maxVisible; ++i) {
            var app = picked[i];
            if (app.runner !== "native") {
                out.push(app);
                continue;
            }
            var entry = root.desktopFor(app);
            if (entry)
                out.push(Object.assign({}, app, { desktopEntry: entry }));
            else if (app.executable)
                out.push(app);
        }
        return out;
    }

    readonly property int count: root.apps.length

    function appAt(index) {
        return index >= 0 && index < root.apps.length ? root.apps[index] : null;
    }

    /** "idle", "launching" or "running". Native desktop entries are not tracked, so they only ever show "launching". */
    function stateFor(index) {
        var app = root.appAt(index);
        if (!app)
            return "idle";
        if (root.launchingId === app.id)
            return "launching";
        return AppLauncher.isRunning(app.id) ? "running" : "idle";
    }

    /** What the app runs on, for the line under its name. */
    function labelFor(index) {
        var app = root.appAt(index);
        return app ? RuntimeManager.profileFor(app.runner).shortLabel : "";
    }

    function launch(index) {
        var app = root.appAt(index);
        if (!app)
            return;

        root.launchingId = app.id;
        launchFeedback.restart();

        if (app.desktopEntry) {
            app.desktopEntry.execute();
            if (AppRegistry.byId(app.id))
                AppRegistry.recordLaunch(app.id);
            return;
        }
        // Anything that needs a runner decision stays behind AppLauncher.
        AppLauncher.launch(app.id, false);
    }

    property Timer launchFeedback: Timer {
        interval: 1800
        onTriggered: root.launchingId = ""
    }
}
