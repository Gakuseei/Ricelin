#!/usr/bin/env python3
"""Self-test for the wallcolors app theme in a temp dir; gsettings, flatpak and notifications never leave the process."""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wallcolors as w  # noqa: E402


class Done:
    returncode = 0
    stdout = ""


def main():
    tmp = Path(tempfile.mkdtemp())
    try:
        run(tmp)
    finally:
        shutil.rmtree(tmp)
    print("\nALL TESTS PASSED")


def run(tmp):
    settings = {"gtk-theme": "Nordic", "color-scheme": "prefer-dark"}
    log = []
    w.gget = settings.get
    w.gset = lambda key, value: (settings.__setitem__(key, value), log.append((key, value)))
    calls = []
    w.subprocess.run = lambda argv, **kw: (calls.append(argv), Done())[1]
    w.time.sleep = lambda s: None
    w.shutil.which = lambda name: "/usr/bin/" + name
    w.STATE, w.GTK4, w.GTK3, w.THEMES = tmp / "state", tmp / "gtk-4.0", tmp / "gtk-3.0", tmp / "themes"
    w.OVERRIDES = tmp / "overrides"
    has_adw = w.find_theme("adw-gtk3-dark") is not None

    w.disable_apps()
    assert settings == {"gtk-theme": "Nordic", "color-scheme": "prefer-dark"} and not log, "off before on changes nothing"
    print("A off without on: ok")

    settings["color-scheme"] = "default"
    w.GTK3.mkdir(parents=True)
    (w.GTK3 / "gtk.css").write_text("/* mine */\n")
    (w.GTK3 / "bookmarks").write_text("file:///tmp\n")
    w.OVERRIDES.write_text("[Context]\nfilesystems=xdg-config/gtk-4.0;\n")
    w.apply_apps(w.STATIC)
    added = [a for a in calls if a[:2] == ["flatpak", "override"]]
    assert added == [["flatpak", "override", "--user", "--filesystem=xdg-data/themes:ro"]], "user's rw gtk-4.0 share kept"
    if has_adw:
        assert (w.GTK3 / "gtk.css.bak").read_text() == "/* mine */\n", "foreign gtk.css backed up"
    else:
        assert (w.GTK3 / "gtk.css").read_text() == "/* mine */\n", "gtk3 css kept without adw-gtk3"
    assert (w.GTK4 / "gtk.css").read_text().startswith(w.MARK), "gtk4 entry written"
    assert "#e0563b" in (w.GTK4 / "ricelin.css").read_text(), "static accent in gtk4 colors"
    assert settings["color-scheme"] == "prefer-dark", "static palette is dark"
    print("B enable: ok")

    log.clear()
    w.apply_apps(w.STATIC)
    assert not log, "unchanged palette touches no setting"
    print("C unchanged: ok")

    before = settings["gtk-theme"]
    w.apply_apps(dict(w.STATIC, primary="#3b8ee0"))
    assert ("color-scheme", "prefer-light") in log and settings["color-scheme"] == "prefer-dark", "same tone double-flips"
    assert not has_adw or settings["gtk-theme"] != before, "gtk3 theme name alternates"
    print("D same tone: ok")

    os.environ["RICELIN_PALETTE"] = "static"
    w.sync_apps(dict(w.STATIC, primary="#00ff00"))
    assert "#e0563b" in (w.GTK4 / "ricelin.css").read_text(), "static mode ignores the wallpaper palette"
    del os.environ["RICELIN_PALETTE"]
    w.apply_apps(dict(w.STATIC, surface="#f0ece8", bright="#1a1410"))
    assert settings["color-scheme"] == "prefer-light", "light palette flips the scheme"
    print("E static and light: ok")

    w.disable_apps()
    assert (w.GTK3 / "gtk.css").read_text() == "/* mine */\n", "foreign gtk.css restored"
    assert (w.GTK3 / "bookmarks").read_text() == "file:///tmp\n", "bookmarks untouched"
    assert not (w.GTK4 / "gtk.css").exists() and not (w.GTK4 / "ricelin.css").exists(), "gtk4 files removed"
    assert settings == {"gtk-theme": "Nordic", "color-scheme": "prefer-dark"}, "own theme restored, default comes back dark"
    assert "filesystems=xdg-config/gtk-4.0;" in w.OVERRIDES.read_text(), "user's flatpak share survives off"
    assert not any((w.THEMES / n).exists() for n in w.RICELIN_THEMES), "theme dirs removed"
    print("F disable: ok")

    settings.update({"gtk-theme": "Adwaita", "color-scheme": "prefer-light"})
    w.apply_apps(w.STATIC)
    w.disable_apps()
    assert settings["gtk-theme"] in ("adw-gtk3-dark", "Adwaita-dark"), "stock Adwaita comes back dark"
    assert settings["color-scheme"] == "prefer-light", "an explicit light choice is kept"
    print("G stock default: ok")
    assert not any(a[0] == "gsettings" for a in calls), "no real gsettings call"

    class Histogram(Done):
        stdout = "  40000: (224,86,59) #E0563B srgb(224,86,59)\n"
    w.subprocess.run = lambda argv, **kw: (calls.append(argv), Histogram())[1]
    w.CACHE = tmp / "cache"
    pic = tmp / "wall.png"
    pic.write_bytes(b"png")
    magick = lambda: sum(a[0] == "magick" for a in calls)
    first = w.cached_analyze(str(pic))
    assert first[0] is not None and w.cached_analyze(str(pic)) == first and magick() == 1, "a re-pick reuses the palette"
    os.utime(pic, ns=(1, 1))
    w.cached_analyze(str(pic))
    assert magick() == 2, "a changed file is analysed again"
    print("H analyze cache: ok")


if __name__ == "__main__":
    main()
