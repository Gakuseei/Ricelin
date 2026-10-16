#!/usr/bin/env python3
"""
Generate the rice colour set from a wallpaper and fan it out to the consumers.
One histogram pass yields both the area-dominant chromatic hue (binned by hue
family so a small vivid accent never hijacks the theme) and the mean lightness.
The mean lightness drives the pill's whole tone: a bright wallpaper makes a light
pill with dark text, a dark or OLED-black one makes a near-black pill with cream
text, so the surfaces and the text flip together for contrast across the full
range. The dominant hue tints every tier in HSL. An achromatic wallpaper drops to
a neutral grey ramp. matugen still builds the dark base16 the always-dark terminal
reads; the pill JSON carries surfaces, accent and the contrast-matched text.
"""
import colorsys
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

CACHE = Path.home() / ".cache" / "ricelin"
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / "ricelin"
GTK4 = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "gtk-4.0"
GTK3 = GTK4.parent / "gtk-3.0"
THEMES = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "themes"
OVERRIDES = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share") / "flatpak" / "overrides" / "global"
FLATPAK_FS = ["xdg-config/gtk-4.0:ro", "xdg-data/themes:ro"]
IFACE = "org.gnome.desktop.interface"
MARK = "/** Ricelin app theme, turn it off in Settings > Appearance */\n"
RICELIN_THEMES = ["Ricelin-a", "Ricelin-b", "Ricelin-base", "Ricelin-base-dark"]
STATIC = {"surface": "#211711", "surface_container_low": "#221813", "surface_container": "#2c2118",
          "surface_container_high": "#2e231b", "outline_variant": "#3a2a22", "primary": "#e0563b",
          "cream": "#e6d6cb", "bright": "#fff6f0"}

SURF_NAMES = ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest", "outline_variant"]
DARK_STEPS = [0.0, 0.022, 0.038, 0.065, 0.100, 0.225]
LIGHT_STEPS = [0.0, -0.045, -0.075, -0.115, -0.160, -0.340]
TEXT_KEYS = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"]
DARK_TEXT = [(0.90, 0.05), (0.97, 0.03), (0.73, 0.07), (0.54, 0.06),
             (0.44, 0.05), (0.81, 0.07), (0.75, 0.08)]
LIGHT_TEXT = [(0.20, 0.18), (0.10, 0.20), (0.36, 0.14), (0.48, 0.10),
              (0.56, 0.08), (0.28, 0.12), (0.34, 0.12)]


def analyze(wallpaper):
    out = subprocess.run(
        ["magick", wallpaper, "-alpha", "off", "-resize", "200x200", "-colors", "48",
         "-format", "%c", "histogram:info:-"],
        capture_output=True, text=True).stdout
    buckets, total, lum, chroma = {}, 0, 0.0, 0
    for line in out.splitlines():
        m = re.search(r"\s*(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6})", line)
        if not m:
            continue
        count, hex_str = int(m.group(1)), m.group(2)
        r, g, b = (int(hex_str[i:i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        total += count
        lum += count * l
        if s < 0.15 or l < 0.05 or l > 0.92:
            continue
        chroma += count
        bucket = buckets.setdefault((int(h * 360) // 30) % 12, {"wsat": 0.0, "best": None})
        bucket["wsat"] += count * s
        score = count * s * (1 if 0.12 < l < 0.55 else 0.4)
        if not bucket["best"] or score > bucket["best"][0]:
            bucket["best"] = (score, h, s)
    mean_l = lum / total if total else 0.0
    if not buckets or chroma < 0.08 * total:
        return None, 0.0, mean_l
    win = max(buckets.values(), key=lambda v: v["wsat"])
    return win["best"][1], win["best"][2], mean_l


def matugen(source_hex):
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def tint(hue, sat, light):
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def lerp(x, x0, x1, y0, y1):
    t = max(0.0, min(1.0, (x - x0) / (x1 - x0)))
    return y0 + t * (y1 - y0)


def render_fastfetch(pill):
    """
    Recolour the fastfetch readout from the same pill palette. fastfetch has no
    daemon, so writing the rendered config is enough, the next run picks it up.
    The accent drives the keys and the torii, the surface ramp the lantern body,
    and a dim text tone the section rules, so it tracks the wallpaper like the
    pill and terminal do.
    """
    ff = Path.home() / ".config" / "fastfetch"
    tmpl = ff / "config.jsonc.in"
    if not tmpl.is_file():
        print("wallcolors: config.jsonc.in missing in ~/.config/fastfetch, skipping "
              "fastfetch recolour (apply the Ricelin update or re-run the installer)",
              file=sys.stderr)
        return
    seq = lambda h: "%d;%d;%d" % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    repl = {
        "__LANTERN__": str(ff / "lantern.txt"),
        "__KEYS__": seq(pill["primary"]),
        "__SEP__": seq(pill["dim"]),
        "__LOGO1__": seq(pill["primary"]),
        "__LOGO2__": seq(pill["on_primary_container"]),
        "__LOGO3__": seq(pill["surface_container"]),
        "__LOGO4__": seq(pill["surface_container_high"]),
        "__LOGO5__": seq(pill["subtle"]),
        "__LOGO6__": seq(pill["outline"]),
        "__LOGO7__": seq(pill["bright"]),
    }
    out = tmpl.read_text()
    for key, val in repl.items():
        out = out.replace(key, val)
    (ff / "config.jsonc").write_text(out)


def flags():
    try:
        return json.loads((STATE / "flags.json").read_text())
    except (OSError, ValueError):
        return {}


def palette_mode():
    return os.environ.get("RICELIN_PALETTE") or flags().get("paletteMode", "static")


def gget(key):
    out = subprocess.run(["gsettings", "get", IFACE, key], capture_output=True, text=True)
    return out.stdout.strip().strip("'")


def gset(key, value):
    subprocess.run(["gsettings", "set", IFACE, key, value], capture_output=True)


def set_scheme(scheme, force):
    """GTK4 only re-reads its user CSS when the colour scheme changes, so an unchanged tone flips out and back."""
    if gget("color-scheme") == scheme:
        if not force:
            return
        gset("color-scheme", "prefer-light" if scheme == "prefer-dark" else "prefer-dark")
        time.sleep(0.25)
    gset("color-scheme", scheme)


def notify(summary, body):
    return subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                           "--object-path", "/org/freedesktop/Notifications",
                           "--method", "org.freedesktop.Notifications.Notify",
                           "Ricelin", "0", "", summary, body, "[]", "{}", "8000"],
                          capture_output=True).returncode == 0


def fs_path(fs):
    return fs.lstrip("!").split(":")[0]


def flatpak_shares():
    """Flatpak keys filesystems by path, so any existing entry for a path, whatever its mode, belongs to the user."""
    shares = []
    for f in (OVERRIDES, Path("/var/lib/flatpak/overrides/global")):
        try:
            for line in f.read_text().splitlines():
                if line.startswith("filesystems="):
                    shares += [fs_path(fs) for fs in line[len("filesystems="):].split(";") if fs]
        except OSError:
            pass
    return shares


def apps_lock():
    STATE.mkdir(parents=True, exist_ok=True)
    lock = open(STATE / "apptheme.lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    return lock


def write_if_changed(path, text):
    try:
        if path.read_text() == text:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def gtk_colors(p, light):
    named = {
        "accent_bg_color": p["primary"], "accent_fg_color": p["bright"] if light else p["surface"],
        "accent_color": p["primary"],
        "window_bg_color": p["surface_container_low"], "view_bg_color": p["surface"],
        "headerbar_bg_color": p["surface_container"], "headerbar_backdrop_color": p["surface_container_low"],
        "headerbar_border_color": p["outline_variant"],
        "sidebar_bg_color": p["surface_container"], "sidebar_backdrop_color": p["surface_container_low"],
        "secondary_sidebar_bg_color": p["surface_container_low"],
        "card_bg_color": p["surface_container_high"], "dialog_bg_color": p["surface_container_high"],
        "popover_bg_color": p["surface_container_high"], "thumbnail_bg_color": p["surface_container_high"],
    }
    for part in ("window", "view", "headerbar", "sidebar", "secondary_sidebar", "card", "dialog",
                 "popover", "thumbnail"):
        named[part + "_fg_color"] = p["cream"]
    return "".join(f"@define-color {k} {v};\n" for k, v in named.items())


def find_theme(name):
    for root in (Path("/usr/share/themes"), Path("/usr/local/share/themes"), THEMES):
        if (root / name / "gtk-3.0" / "gtk.css").is_file():
            return root / name
    return None


def base_theme(light):
    """Flatpak apps only see ~/.local/share/themes, so adw-gtk3 is mirrored there for the wrappers to import."""
    src = find_theme("adw-gtk3" if light else "adw-gtk3-dark")
    if not src:
        return None
    dst = THEMES / ("Ricelin-base" if light else "Ricelin-base-dark")
    css = dst / "gtk-3.0" / "gtk.css"
    if not css.is_file() or (src / "gtk-3.0" / "gtk.css").stat().st_mtime > css.stat().st_mtime:
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst)
    return dst.name


def enable_apps():
    state = {"gtk-theme": gget("gtk-theme"), "color-scheme": gget("color-scheme"),
             "backups": [], "flatpak": [], "notified": False}
    for d in [GTK4] + ([GTK3] if find_theme("adw-gtk3-dark") else []):
        css = d / "gtk.css"
        if css.is_file() and not css.read_text(errors="ignore").startswith(MARK):
            bak = next(b for b in [d / "gtk.css.bak"] + [d / f"gtk.css.bak.{n}" for n in range(1, 100)]
                       if not b.exists())
            css.rename(bak)
            state["backups"].append(str(bak))
    if shutil.which("flatpak"):
        have = flatpak_shares()
        state["flatpak"] = [fs for fs in FLATPAK_FS if fs_path(fs) not in have]
        if state["flatpak"]:
            subprocess.run(["flatpak", "override", "--user"]
                           + ["--filesystem=" + fs for fs in state["flatpak"]], capture_output=True)
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / "apptheme.json").write_text(json.dumps(state, indent=2) + "\n")


def remind_backups():
    """The first apply can run at login before the pill owns the notification bus, so the toast retries until it lands."""
    f = STATE / "apptheme.json"
    state = json.loads(f.read_text())
    if state.get("backups") and not state.get("notified") and notify(
            "App theme is on", "Your own gtk.css was moved to "
            + ", ".join(b.replace(str(Path.home()), "~") for b in state["backups"])
            + ". Turning App theme off puts it back."):
        state["notified"] = True
        f.write_text(json.dumps(state, indent=2) + "\n")


def apply_apps(p):
    """Theme GTK3 and GTK4 apps from the pill palette; the alternating Ricelin-a/b name makes running GTK3 apps reload."""
    if not (STATE / "apptheme.json").is_file():
        enable_apps()
    r, g, b = (int(p["surface"][i:i + 2], 16) / 255 for i in (1, 3, 5))
    light = colorsys.rgb_to_hls(r, g, b)[1] > 0.5
    colors = gtk_colors(p, light)
    root = ":root { --accent-bg-color: @accent_bg_color; --accent-fg-color: @accent_fg_color; --accent-color: %s; }\n"
    changed = write_if_changed(GTK4 / "ricelin.css", colors + root % p["primary"])
    if not (GTK4 / "gtk.css").exists():
        write_if_changed(GTK4 / "gtk.css", MARK + '@import url("ricelin.css");\n')
    base = base_theme(light)
    if base:
        css3 = MARK + f'@import url("../../{base}/gtk-3.0/gtk.css");\n' + colors
        current = gget("gtk-theme")
        try:
            same = current in RICELIN_THEMES[:2] and (THEMES / current / "gtk-3.0" / "gtk.css").read_text() == css3
        except OSError:
            same = False
        if not same:
            target = "Ricelin-b" if current == "Ricelin-a" else "Ricelin-a"
            write_if_changed(THEMES / target / "gtk-3.0" / "gtk.css", css3)
            write_if_changed(THEMES / target / "gtk-4.0" / "gtk.css", f'@import url("../../{base}/gtk-4.0/gtk.css");\n')
            gset("gtk-theme", target)
            changed = True
    set_scheme("prefer-light" if light else "prefer-dark", changed)
    remind_backups()


def disable_apps():
    """Put the user's own GTK setup back; the stock light Linux default comes back dark to match the rice."""
    try:
        state = json.loads((STATE / "apptheme.json").read_text())
    except (OSError, ValueError):
        state = None
    css = GTK4 / "gtk.css"
    if css.is_file() and css.read_text(errors="ignore").startswith(MARK):
        css.unlink()
    (GTK4 / "ricelin.css").unlink(missing_ok=True)
    if state is None and gget("gtk-theme") not in RICELIN_THEMES:
        return
    state = state or {}
    for bak in map(Path, state.get("backups", [])):
        if bak.is_file() and not (bak.parent / "gtk.css").exists():
            bak.rename(bak.parent / "gtk.css")
    theme = state.get("gtk-theme", "")
    if theme in ("", "Adwaita", *RICELIN_THEMES):
        theme = "adw-gtk3-dark" if find_theme("adw-gtk3-dark") else "Adwaita-dark"
    gset("gtk-theme", theme)
    scheme = state.get("color-scheme", "")
    set_scheme("prefer-dark" if scheme in ("", "default") else scheme, True)
    for name in RICELIN_THEMES:
        shutil.rmtree(THEMES / name, ignore_errors=True)
    if state.get("flatpak"):
        try:
            lines = OVERRIDES.read_text().splitlines()
            out = []
            for line in lines:
                if line.startswith("filesystems="):
                    keep = [fs for fs in line[len("filesystems="):].split(";") if fs and fs not in state["flatpak"]]
                    if not keep:
                        continue
                    line = "filesystems=" + ";".join(keep) + ";"
                out.append(line)
            if out == ["[Context]"]:
                OVERRIDES.unlink()
            else:
                OVERRIDES.write_text("\n".join(out) + "\n")
        except OSError:
            pass
    (STATE / "apptheme.json").unlink(missing_ok=True)


def sync_apps(pill, need_flag=False):
    try:
        with apps_lock():
            if need_flag and not flags().get("appTheme"):
                return
            apply_apps(STATIC if palette_mode() == "static" else pill)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"wallcolors: app theme skipped: {exc}", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        return 1
    if sys.argv[1] == "--apps":
        if sys.argv[2:3] == ["off"]:
            with apps_lock():
                disable_apps()
            return 0
        try:
            pill = json.loads((CACHE / "colors.json").read_text())
        except (OSError, ValueError):
            pill = STATIC
        sync_apps(pill)
        return 0
    if sys.argv[1] == "--hue":
        hue = (float(sys.argv[2]) % 360) / 360.0
        mode = sys.argv[3] if len(sys.argv) > 3 else "dark"
        sat = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
        sat = max(0.0, min(1.0, sat))
        mean_l = 0.85 if mode == "light" else 0.12
        chromatic = sat > 0.02
    else:
        wallpaper = sys.argv[1]
        if not Path(wallpaper).is_file():
            return 0
        hue, sat, mean_l = analyze(wallpaper)
        chromatic = hue is not None
        if not chromatic:
            hue, sat = 0.09, 0.0
    CACHE.mkdir(parents=True, exist_ok=True)

    light = mean_l >= 0.40
    surf_sat = min(sat, 0.26) if light else min(max(sat, 0.30 if chromatic else 0.0), 0.45)
    acc_sat = (min(sat + 0.18, 0.85) if light else min(max(sat, 0.30) + 0.12, 0.82)) if chromatic else 0.05
    if light:
        base = lerp(mean_l, 0.40, 0.66, 0.80, 0.93)
        steps, text, acc_l, deep_l, glow_l = LIGHT_STEPS, LIGHT_TEXT, 0.42, 0.30, 0.55
    else:
        base = lerp(mean_l, 0.0, 0.40, 0.045, 0.20)
        steps, text, acc_l, deep_l, glow_l = DARK_STEPS, DARK_TEXT, 0.70, 0.34, 0.86

    pill = {name: tint(hue, surf_sat, base + step) for name, step in zip(SURF_NAMES, steps)}
    pill["primary"] = tint(hue, acc_sat, acc_l)
    pill["primary_container"] = tint(hue, min(acc_sat + 0.08, 0.9), deep_l)
    pill["on_primary_container"] = tint(hue, min(acc_sat, 0.45), glow_l)
    pill["outline"] = tint(hue, surf_sat, base + (-0.35 if light else 0.35))
    for key, (lit, st) in zip(TEXT_KEYS, text):
        pill[key] = tint(hue, st, lit)
    (CACHE / "colors.json").write_text(json.dumps(pill, indent=2) + "\n")
    render_fastfetch(pill)
    if flags().get("appTheme"):
        sync_apps(pill, need_flag=True)

    try:
        b = {k: v["dark"]["color"] for k, v in
             matugen(tint(hue, sat, 0.45) if chromatic else "#787878")["base16"].items()}
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return 0

    (CACHE / "hypr-colors.lua").write_text(
        'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
        % (pill["primary"], b["base01"]))

    lines = [
        f'background = {b["base00"]}',
        f'foreground = {b["base07"]}',
        f'cursor-color = {pill["primary"]}',
        f'selection-background = {b["base02"]}',
        f'selection-foreground = {b["base07"]}',
    ]
    for i in range(16):
        lines.append(f'palette = {i}={b["base%02x" % i]}')
    (CACHE / "ghostty-colors").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
