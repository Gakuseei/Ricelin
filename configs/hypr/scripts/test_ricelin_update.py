#!/usr/bin/env python3
"""
Self-test for ricelin-update.py against throwaway git repos in a temp dir. No
network, no touching the user's real config. Builds a fake origin with a couple of
commits (some carrying changelog: trailers, some not) and a fake live config, then
drives check/apply through the engine and asserts the merge classes behave.
"""
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("ricelin_update", HERE / "ricelin-update.py")
ru = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ru)


def git(repo, *args):
    env = dict(os.environ)
    env.update({
        "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
        "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t",
    })
    subprocess.run(["git", "-C", str(repo), *args], check=True,
                   capture_output=True, text=True, env=env)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def main():
    tmp = Path(tempfile.mkdtemp())
    origin = tmp / "origin"
    data = tmp / "data" / "ricelin-update"
    state = tmp / "state"
    config = tmp / "config"

    os.environ["XDG_DATA_HOME"] = str(tmp / "data")
    os.environ["XDG_STATE_HOME"] = str(state)
    assert ru.data_dir() == data

    origin.mkdir(parents=True)
    git(origin, "init", "-q", "-b", "main")

    binds = "configs/hypr/modules/binds.lua"
    monitors = "configs/hypr/modules/monitors.lua"
    pill = "configs/quickshell/pill/Look.qml"

    write(origin / binds, "bind one\nspacer\nspacer\nbind two\nspacer\nspacer\nbind three\n")
    write(origin / monitors, "monitor A\nspacer\nspacer\nmonitor B\nspacer\nspacer\ntail\n")
    write(origin / pill, "code v1\n")
    write(origin / "configs/hypr/scripts/tool.sh", "#!/bin/sh\necho tool\n")
    write(origin / "configs/quickshell/pill/App/ricelin-settings.desktop", "[Desktop Entry]\n")
    write(origin / "configs/hypr/scripts/test_tool.py", "harness\n")
    write(origin / "configs/kde/kdeglobals", "[General]\n")
    write(origin / "configs/sddm/themes/torii/Main.qml", "greeter\n")
    write(origin / "configs/grub/10_ricelin", "entry\n")
    write(origin / "configs/brave-theme/manifest.json", "{}\n")
    for name in ("distro.py", "pkg.py"):
        write(origin / "installer" / name, (HERE.parents[2] / "installer" / name).read_text())
    git(origin, "add", "-A")
    git(origin, "commit", "-q", "-m", "init")

    write(origin / pill, "code v2\n")
    git(origin, "add", "-A")
    git(origin, "commit", "-q", "-m", "refactor pill\n\nchangelog: faster pill open")

    write(origin / pill, "code v3\n")
    git(origin, "add", "-A")
    git(origin, "commit", "-q", "-m", "tidy up internals")

    write(origin / binds, "bind one\nspacer\nspacer\nbind two changed upstream\nspacer\nspacer\nbind three\n")
    write(origin / monitors, "monitor A\nspacer\nspacer\nmonitor B\nspacer\nspacer\nmonitor C upstream\n")
    git(origin, "add", "-A")
    git(origin, "commit", "-q", "-m", "config bump\n\nchangelog: new monitor preset")

    """First run baselines protected files and copies code, no merge yet."""
    write(config / "hypr/modules/binds.lua", "bind one\nspacer\nspacer\nbind two\nspacer\nspacer\nbind three\n")
    write(config / "hypr/modules/monitors.lua", "monitor A\nspacer\nspacer\nmonitor B\nspacer\nspacer\ntail\n")
    write(config / "quickshell/pill/Look.qml", "stale local code\n")
    write(config / "hypr/hypridle.conf", "after_sleep_cmd = hyprctl dispatch dpms on\n"
          "on-timeout = hyprctl dispatch dpms off\non-resume = hyprctl dispatch dpms on\n")

    first = ru.run("apply", str(origin), config, set(), set())
    assert first["status"] == "ok", first
    assert first["applied"] is True
    assert (config / "quickshell/pill/Look.qml").read_text() == "code v3\n", "code must overwrite"
    assert (config / "quickshell/pill/Look.qml.bak").read_text() == "stale local code\n", "a local code edit is kept as .bak"
    assert not (config / "hypr/scripts/tool.sh.bak").exists(), "an untouched code file gets no .bak"
    assert ru.manifest_path().read_text(), "manifest written"
    assert os.access(config / "hypr/scripts/tool.sh", os.X_OK), "synced scripts stay executable"
    assert (config / "quickshell/pill/Look.qml").stat().st_mode & 0o777 == 0o644, "synced code files are 0644"
    print("first-run baseline + code overwrite: ok")

    assert (config / "kdeglobals").read_text() == "[General]\n", "kde/kdeglobals lands at kdeglobals"
    for skipped in ("kde", "sddm", "grub", "brave-theme", "hypr/scripts/test_tool.py"):
        assert not (config / skipped).exists(), f"{skipped} is outside the deploy set"
    print("sync follows the installer deploy set: ok")

    assert ru.native_install_argv("debian", ["x"])[:2] == ["env", "DEBIAN_FRONTEND=noninteractive"]
    assert "exec(" not in Path(ru.__file__).read_text(), "the engine never runs code from the clone"
    print("dependency step stays on the engine's own helpers: ok")

    assert (config / "hypr/hypridle.conf").read_text() == (
        "after_sleep_cmd = hyprctl dispatch \"hl.dsp.dpms({ action = 'on' })\"\n"
        "on-timeout = hyprctl dispatch \"hl.dsp.dpms({ action = 'off' })\"\n"
        "on-resume = hyprctl dispatch \"hl.dsp.dpms({ action = 'on' })\"\n")
    print("hypridle dpms migration: ok")

    entry = ru.settings_entry_link()
    shipped = (config / "quickshell/pill/App/ricelin-settings.desktop").resolve()
    assert entry == tmp / "data/applications/ricelin-settings.desktop", entry
    assert entry.is_symlink() and entry.resolve() == shipped, "apply links the launcher entry"
    assert ru.link_settings_entry(config) is False and entry.resolve() == shipped, "a correct link is left alone"
    entry.unlink()
    entry.symlink_to(tmp / "gone.desktop")
    assert ru.link_settings_entry(config) is True and entry.resolve() == shipped, "a stale link is repointed"
    entry.unlink()
    entry.write_text("mine\n")
    assert ru.link_settings_entry(config) is False and entry.read_text() == "mine\n", "a user's own entry file stays"
    entry.unlink()
    print("settings launcher entry: ok")

    """
    Diverge the user locally without overlapping the upstream config-bump lines.
    binds: user edits line one (upstream touched line two) -> clean auto-merge.
    monitors: user edits line two (upstream appended a line) -> clean auto-merge.
    Then move origin/main forward by re-pointing the manifest base to the commit
    before the config bump so the engine sees an upstream change to merge.
    """
    base_before_bump = ru.git(data, "rev-parse", "HEAD~1").strip()
    head = ru.git(data, "rev-parse", "HEAD").strip()
    import json
    m = json.loads(ru.manifest_path().read_text())
    m["syncedSha"] = base_before_bump
    m["modules"][binds[len("configs/"):]] = base_before_bump
    m["modules"][monitors[len("configs/"):]] = base_before_bump
    ru.manifest_path().write_text(json.dumps(m))

    write(config / "hypr/modules/binds.lua", "bind one local\nspacer\nspacer\nbind two\nspacer\nspacer\nbind three\n")
    write(config / "hypr/modules/monitors.lua", "monitor A\nspacer\nspacer\nmonitor B local\nspacer\nspacer\ntail\n")

    res = ru.run("check", str(origin), config, set(), set())
    states = {r["name"]: r["state"] for r in res["modules"]}
    assert states["binds"] == "merged", states
    assert states["monitors"] == "merged", states
    assert "faster pill open" not in res["changelog"], "changelog out of range excluded"
    assert "new monitor preset" in res["changelog"], res["changelog"]
    assert res["behind"] == 1, res["behind"]
    print("non-overlapping diverge -> clean merge, changelog range: ok")

    apply_res = ru.run("apply", str(origin), config, set(), set())
    binds_out = (config / "hypr/modules/binds.lua").read_text()
    assert "bind one local" in binds_out and "bind two changed upstream" in binds_out, binds_out
    assert "monitor C upstream" in (config / "hypr/modules/monitors.lua").read_text()
    print("merged write keeps both edits: ok")

    """Overlapping edit: reset base + diverge on the SAME line upstream changed."""
    m = json.loads(ru.manifest_path().read_text())
    m["syncedSha"] = base_before_bump
    m["modules"][binds[len("configs/"):]] = base_before_bump
    ru.manifest_path().write_text(json.dumps(m))
    write(config / "hypr/modules/binds.lua", "bind one\nspacer\nspacer\nbind two mine\nspacer\nspacer\nbind three\n")
    conflict_before = (config / "hypr/modules/binds.lua").read_text()

    conf = ru.run("apply", str(origin), config, set(), set())
    states = {r["name"]: r["state"] for r in conf["modules"]}
    assert states["binds"] == "conflict", states
    assert binds[len("configs/"):] in conf["conflicts"], conf["conflicts"]
    assert (config / "hypr/modules/binds.lua").read_text() == conflict_before, "conflict leaves live file untouched"
    print("overlapping edit -> conflict, live file untouched: ok")

    """--take pulls the upstream version of a conflicting file wholesale."""
    m = json.loads(ru.manifest_path().read_text())
    m["modules"][binds[len("configs/"):]] = base_before_bump
    ru.manifest_path().write_text(json.dumps(m))
    taken = ru.run("apply", str(origin), config, {binds[len("configs/"):]}, set())
    assert (config / "hypr/modules/binds.lua").read_text() == "bind one\nspacer\nspacer\nbind two changed upstream\nspacer\nspacer\nbind three\n"
    print("--take overwrites conflicting file: ok")

    """
    C1: a quickshell-only symlink into a git work-tree is devmode. Without the fix
    is_devmode only inspected hypr, so an apply would write straight through the
    quickshell symlink into the real worktree.
    """
    dev_root = tmp / "devconfig"
    dev_root.mkdir(parents=True)
    worktree = tmp / "devworktree"
    worktree.mkdir(parents=True)
    git(worktree, "init", "-q", "-b", "main")
    write(worktree / "configs/quickshell/pill/Look.qml", "live uncommitted work\n")
    (dev_root / "quickshell").symlink_to(worktree / "configs/quickshell")
    assert ru.is_devmode(dev_root) is True, "quickshell-only symlink must be devmode"
    assert ru.run("check", str(origin), dev_root, set(), set())["status"] == "devmode"

    rel_root = tmp / "relconfig"
    rel_root.mkdir(parents=True)
    os.symlink(os.path.relpath(worktree / "configs/quickshell", rel_root), rel_root / "quickshell")
    assert ru.is_devmode(rel_root) is True, "relative quickshell symlink must resolve to devmode"

    plain_root = tmp / "plainconfig"
    (plain_root / "quickshell").mkdir(parents=True)
    assert ru.is_devmode(plain_root) is False, "real dir, not a symlink, is not devmode"
    print("C1 quickshell-only symlink -> devmode: ok")

    """
    H2: a trailing flag with no value must still emit one JSON object and exit 0,
    never a bare IndexError traceback. main parses args inside its guard now.
    """
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = ru.main(["check", "--config-root", str(config), "--remote"])
    out = buf.getvalue().strip()
    assert code == 0, code
    obj = json.loads(out)
    assert obj["status"] == "error" and obj["error"], obj
    assert out.count("\n") == 0, "exactly one JSON line"
    print("H2 bad trailing flag -> valid JSON, exit 0: ok")

    """
    M1: a present but unparseable manifest is corrupt, surfaced as an error status,
    never silently reset to a first run that re-baselines every protected file.
    """
    ru.manifest_path().write_text("{ this is not json")
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = ru.main(["check", "--config-root", str(config), "--remote", str(origin)])
    corrupt = json.loads(buf.getvalue())
    assert code == 0, code
    assert corrupt["status"] == "error", corrupt
    assert "corrupt" in corrupt["error"].lower(), corrupt
    assert corrupt["modules"] == [] and corrupt["behind"] == 0, "must not masquerade as first run"
    print("M1 corrupt manifest -> error, not first run: ok")

    print("\nALL TESTS PASSED")


if __name__ == "__main__":
    main()
