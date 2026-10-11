pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function create(app) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path) return false;
        var isUmu = app && app.runner === "umu";
        Quickshell.execDetached(["sh", "-c", isUmu
            ? "mkdir -p -- \"$1\""
            : "set -e; mkdir -p -- \"$1\"; WINEPREFIX=\"$1\" WINEARCH=win64 wineboot --init", "_", path]);
        return true;
    }

    function openFiles(app) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path) return false;
        Quickshell.execDetached(["sh", "-c", "xdg-open -- \"$1/drive_c\" 2>/dev/null || xdg-open -- \"$1\"", "_", path]);
        return true;
    }

    function winetricks(app) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path) return false;
        Quickshell.execDetached(["sh", "-c", "WINEPREFIX=\"$1\" winetricks", "_", path]);
        return true;
    }

    function clone(app, destPath) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path || !destPath) return false;
        Quickshell.execDetached(["sh", "-c", "set -e; mkdir -p -- \"$2\"; cp -a -- \"$1/.\" \"$2/\"", "_", path, destPath]);
        return true;
    }

    function reset(app) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path) return false;
        var isUmu = app && app.runner === "umu";
        Quickshell.execDetached(["sh", "-c", isUmu
            ? "rm -rf -- \"$1\"; mkdir -p -- \"$1\""
            : "set -e; rm -rf -- \"$1\"; mkdir -p -- \"$1\"; WINEPREFIX=\"$1\" WINEARCH=win64 wineboot --init", "_", path]);
        return true;
    }

    function remove(app) {
        var path = app && app.prefix ? String(app.prefix) : "";
        if (!path) return false;
        Quickshell.execDetached(["rm", "-rf", "--", path]);
        return true;
    }
}
