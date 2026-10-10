pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Windows-application compatibility layer, abstracted so AddApplicationSheet
 * and AppEditor never have to ask "Wine or Wine-Staging or UMU?" directly.
 * One detection pass on startup (and on demand via rescan()) answers what's
 * actually installed; recommend() turns an app's declared graphics API into
 * a runner + Proton build suggestion, mirroring the split the shell-function
 * era already had by hand (UMU+GE-Proton for the D3D12 title, plain Wine for
 * the two D3D9/D3D11 ones).
 *
 * Detection is deliberately conservative: it reports what it can prove
 * (a binary on $PATH, a directory that looks like a Proton build) rather
 * than trying to fully resolve DXVK/VKD3D component versions, which live
 * per-prefix, not system-wide, and are best left to `winetricks` itself.
 */
Singleton {
    id: root

    property bool ready: false

    property bool hasWine: false
    property string wineVersion: ""
    property bool hasWineStaging: false

    property bool hasUmu: false
    property string umuVersion: ""

    property bool hasSteam: false

    /** [{ name: "GE-Proton10-3", path: "..." }, ...], newest-looking first. */
    property var protonBuilds: []

    property bool hasGamescope: false
    property bool hasMangohud: false
    property bool hasWinetricks: false
    property bool hasZenity: false
    property bool hasKdialog: false

    readonly property bool hasAnyWindowsRuntime: root.hasWine || root.hasUmu

    readonly property var runtimeProfiles: [
        { id: "wine", label: "Wine", shortLabel: "Wine", family: "wine", description: "Direct Windows API compatibility layer" },
        { id: "wine-staging", label: "Wine-Staging", shortLabel: "Staging", family: "wine-staging", description: "Experimental Wine build" },
        { id: "umu", label: "UMU / Proton", shortLabel: "UMU", family: "umu", description: "Proton runtime for non-Steam Windows games" },
        { id: "steam", label: "Steam / Proton", shortLabel: "Steam", family: "steam", description: "Steam-managed title, launched through Steam itself" },
        { id: "native", label: "Native Linux", shortLabel: "Native", family: "native", description: "Use the Linux executable directly" }
    ]

    function profileFor(id) {
        for (var i = 0; i < root.runtimeProfiles.length; i++)
            if (root.runtimeProfiles[i].id === id)
                return root.runtimeProfiles[i];
        return { id: id, label: id, shortLabel: id, family: id, description: "" };
    }

    function runtimeAvailable(id) {
        if (id === "wine") return root.hasWine;
        if (id === "wine-staging") return root.hasWineStaging || root.hasWine;
        if (id === "umu") return root.hasUmu;
        if (id === "steam") return root.hasSteam;
        return id === "native";
    }

    readonly property var availableRuntimeProfiles: root.runtimeProfiles.filter(p => root.runtimeAvailable(p.id));

    /**
     * What a picker should actually offer: the available set, plus — always —
     * whichever runner the app already has, even if detection hasn't
     * resolved yet or reports it missing. Without this, opening the editor
     * for an already-working app during the ~1 detection round-trip after
     * Quickshell starts (or on any false negative) shows a picker with
     * nothing selected, on a config that works fine.
     */
    function selectableProfiles(currentId) {
        var list = root.availableRuntimeProfiles.slice();
        if (currentId && currentId.length > 0 && !list.some(p => p.id === currentId))
            list = list.concat([root.profileFor(currentId)]);
        return list;
    }

    /**
     * graphicsApi -> { runner, protonBuild, reason }. "unknown" and anything
     * without a strong D3D12 signal falls back to plain Wine so a first-time
     * add never requires a Proton build the user might not have; D3D12 is
     * the one case UMU + a Proton build is close to mandatory for.
     */
    function recommend(app) {
        var api = app && app.graphicsApi ? app.graphicsApi : "unknown";
        if (api === "d3d12" && root.hasUmu && root.protonBuilds.length > 0) {
            return { runner: "umu", protonBuild: root.protonBuilds[0].name, reason: "Direct3D 12 — UMU + " + root.protonBuilds[0].name + " carries VKD3D-Proton." };
        }
        if (api === "d3d12" && root.hasUmu) {
            return { runner: "umu", protonBuild: "GE-Proton", reason: "Direct3D 12 wants UMU + Proton, but no local build was found under compatibilitytools.d — install GE-Proton or point Proton build at one manually." };
        }
        if ((api === "d3d9" || api === "d3d11") && root.hasWine) {
            return { runner: "wine", protonBuild: "", reason: (api === "d3d9" ? "Direct3D 9" : "Direct3D 11") + " runs well under Wine + DXVK." };
        }
        if (root.hasWineStaging) {
            return { runner: "wine-staging", protonBuild: "", reason: "No graphics API detected — Wine-Staging is the safest default for a plain Windows utility." };
        }
        if (root.hasWine) {
            return { runner: "wine", protonBuild: "", reason: "Defaulting to Wine." };
        }
        if (root.hasUmu) {
            return { runner: "umu", protonBuild: root.protonBuilds.length > 0 ? root.protonBuilds[0].name : "GE-Proton", reason: "Wine isn't on PATH — falling back to UMU." };
        }
        return { runner: "wine", protonBuild: "", reason: "No compatibility layer detected yet — install Wine or UMU, then Rescan." };
    }

    function rescan() {
        root.ready = false;
        detectProc.running = true;
    }

    Component.onCompleted: root.rescan()

    Process {
        id: detectProc
        command: ["sh", "-c",
            "if command -v wine >/dev/null 2>&1; then echo \"WINE $(wine --version 2>/dev/null)\"; fi; "
            + "if wine --version 2>/dev/null | grep -qi staging; then echo 'STAGING 1'; elif command -v wine-staging >/dev/null 2>&1; then echo 'STAGING 1'; fi; "
            + "if command -v umu-run >/dev/null 2>&1; then echo \"UMU $(umu-run --version 2>/dev/null || echo present)\"; fi; "
            + "command -v steam >/dev/null 2>&1 && echo 'STEAM 1'; "
            + "for d in \"$HOME/.local/share/Steam/compatibilitytools.d\" \"$HOME/.steam/root/compatibilitytools.d\" \"$HOME/.steam/steam/compatibilitytools.d\"; do "
            + "  [ -d \"$d\" ] || continue; for p in \"$d\"/*/; do [ -d \"$p\" ] || continue; b=$(basename \"$p\"); echo \"PROTON $b|$p\"; done; "
            + "done; "
            + "command -v gamescope >/dev/null 2>&1 && echo 'GAMESCOPE 1'; "
            + "command -v mangohud >/dev/null 2>&1 && echo 'MANGOHUD 1'; "
            + "command -v winetricks >/dev/null 2>&1 && echo 'WINETRICKS 1'; "
            + "command -v zenity >/dev/null 2>&1 && echo 'ZENITY 1'; "
            + "command -v kdialog >/dev/null 2>&1 && echo 'KDIALOG 1'; "
            + "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var wine = false, wineVer = "", staging = false, umu = false, umuVer = "", steam = false;
                var builds = [], gamescope = false, mangohud = false, winetricks = false, zenity = false, kdialog = false;
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (line.length === 0)
                        continue;
                    var sp = line.indexOf(" ");
                    var tag = sp >= 0 ? line.slice(0, sp) : line;
                    var rest = sp >= 0 ? line.slice(sp + 1) : "";
                    if (tag === "WINE") {
                        wine = true;
                        wineVer = rest.trim();
                    } else if (tag === "STAGING") {
                        staging = true;
                    } else if (tag === "UMU") {
                        umu = true;
                        umuVer = rest.trim();
                    } else if (tag === "STEAM") {
                        steam = true;
                    } else if (tag === "PROTON") {
                        var parts = rest.split("|");
                        if (parts.length === 2)
                            builds.push({ name: parts[0], path: parts[1] });
                    } else if (tag === "GAMESCOPE") {
                        gamescope = true;
                    } else if (tag === "MANGOHUD") {
                        mangohud = true;
                    } else if (tag === "WINETRICKS") {
                        winetricks = true;
                    } else if (tag === "ZENITY") {
                        zenity = true;
                    } else if (tag === "KDIALOG") {
                        kdialog = true;
                    }
                }
                /** GE builds tend to sort correctly by plain string descend (…10-3 > …9-27); good enough for "put the newest-looking one first". */
                builds.sort((a, b) => b.name.localeCompare(a.name, undefined, { numeric: true }));
                root.hasWine = wine;
                root.wineVersion = wineVer;
                root.hasWineStaging = staging;
                root.hasUmu = umu;
                root.umuVersion = umuVer;
                root.hasSteam = steam;
                root.protonBuilds = builds;
                root.hasGamescope = gamescope;
                root.hasMangohud = mangohud;
                root.hasWinetricks = winetricks;
                root.hasZenity = zenity;
                root.hasKdialog = kdialog;
                root.ready = true;
            }
        }
    }
}
