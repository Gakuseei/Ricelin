#!/usr/bin/env python3
"""Wallpaper or Manual hue to OKLCH rice colours for the pill, lock, fastfetch, GTK, ghostty and Hyprland."""
import colorsys
import fcntl
import json
import math
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

ANALYZE_VERSION = 2
HIST_LINE = re.compile(r"\s*(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6})")
SURF_NAMES = ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest", "outline_variant"]
DARK_STEPS = [0.0, 0.012, 0.028, 0.045, 0.070, 0.130]
LIGHT_STEPS = [0.0, -0.018, -0.032, -0.048, -0.070, -0.160]
TEXT_KEYS = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"]
DARK_TEXT = [0.90, 0.97, 0.76, 0.62, 0.52, 0.83, 0.79]
LIGHT_TEXT = [0.27, 0.18, 0.42, 0.53, 0.62, 0.34, 0.40]
TEXT_MIN = [4.5, 4.5, 4.5, 3.0, 1.8, 4.5, 3.0]
NEUTRAL = {"mean_l": 0.0, "base": None, "accent": None}


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def lerp(x, x0, x1, y0, y1):
    return y0 + clamp((x - x0) / (x1 - x0)) * (y1 - y0)


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_gamma(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def oklch(rgb):
    r, g, b = map(to_linear, rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def _lch_linear(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def lch(L, C, h):
    """OKLCH to sRGB hex, keeping lightness and hue and giving up chroma until it fits the gamut."""
    L = clamp(L)
    fits = lambda c: all(-1e-7 <= x <= 1 + 1e-7 for x in _lch_linear(L, c, h))
    if not fits(C):
        lo, hi = 0.0, C
        for _ in range(20):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if fits(mid) else (lo, mid)
        C = lo
    return "#%02x%02x%02x" % tuple(round(clamp(to_gamma(clamp(x))) * 255) for x in _lch_linear(L, C, h))


def rgb(hex_str):
    return tuple(int(hex_str[i:i + 2], 16) / 255 for i in (1, 3, 5))


def luminance(hex_str):
    r, g, b = map(to_linear, rgb(hex_str))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(x, y):
    hi, lo = sorted((luminance(x), luminance(y)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def hue_dist(a, b):
    return abs((a - b + 180) % 360 - 180)


def circ_mean(pairs):
    x = sum(w * math.cos(math.radians(h)) for w, h in pairs)
    y = sum(w * math.sin(math.radians(h)) for w, h in pairs)
    return math.degrees(math.atan2(y, x)) % 360


def percentile(pairs, q):
    pairs = sorted(pairs)
    goal, run = q * sum(w for _, w in pairs), 0.0
    for value, w in pairs:
        run += w
        if run >= goal:
            return value
    return pairs[-1][0] if pairs else 0.0


def smooth(bins):
    return [sum(bins[(i + k) % 72] * math.exp(-k * k / 8) for k in range(-6, 7)) for i in range(72)]


def _base(px, total):
    weight = lambda n, L, C: n * clamp((C - 0.012) / 0.05) * (1.0 if 0.1 < L < 0.95 else 0.3)
    bins = [0.0] * 72
    for n, L, C, h in px:
        bins[int(h // 5) % 72] += weight(n, L, C)
    if sum(bins) < 0.06 * total:
        return None
    sm = smooth(bins)
    peak = max(range(72), key=sm.__getitem__) * 5 + 2.5
    fam = [(n, L, C, h) for n, L, C, h in px if C >= 0.012 and hue_dist(h, peak) <= 30]
    hue = circ_mean([(weight(n, L, C), h) for n, L, C, h in fam])
    return [round(hue, 2), round(percentile([(C, n) for n, L, C, h in fam], 0.7), 4)]


def _families(px, total):
    """Vivid colour families, a 45 degree hue window per bin: (salience, hue, area, mean chroma, lightness, centre)."""
    vivid = [(n, L, C, h) for n, L, C, h in px if C >= 0.04 and 0.2 < L < 0.96]
    sums = [[0.0] * 5 for _ in range(72)]
    for n, L, C, h in vivid:
        s, w = sums[int(h // 5) % 72], n * C * C
        s[0] += n
        s[1] += n * C
        s[2] += n * C * L
        s[3] += w * math.cos(math.radians(h))
        s[4] += w * math.sin(math.radians(h))
    fams = []
    for i in range(72):
        area, cw, lw, x, y = (sum(sums[(i + k) % 72][j] for k in range(-4, 5)) for j in range(5))
        if area < 0.004 * total:
            continue
        mean_c, lit = cw / area, lw / cw
        hue = math.degrees(math.atan2(y, x)) % 360
        fams.append(((area / total) ** 0.4 * mean_c ** 2.5 * (1.0 if 0.3 < lit < 0.92 else 0.6),
                     hue, area / total, mean_c, lit, i * 5 + 2.5))
    return vivid, fams


def _accent(px, total, base):
    """The most salient vivid family, preferring a real highlight outside the base hue over a stronger base."""
    vivid, fams = _families(px, total)
    if not fams:
        return None
    far = [f for f in fams if base and hue_dist(f[1], base[0]) > 50
           and f[3] >= max(0.055, 0.5 * base[1]) and f[2] >= 0.006]
    _, hue, _, _, lit, centre = max(far or fams)
    mem = [(n, L, C, h) for n, L, C, h in vivid if hue_dist(h, centre) <= 22.5]
    return [round(hue, 2), round(percentile([(C, n) for n, L, C, h in mem], 0.8), 4), round(lit, 4)]


def features(histogram):
    """Mean lightness, area-dominant family (base) and most salient vivid colour (accent) of a magick histogram."""
    px, total, hls = [], 0, 0.0
    for line in histogram.splitlines():
        m = HIST_LINE.match(line)
        if not m:
            continue
        n, col = int(m.group(1)), tuple(int(m.group(2)[i:i + 2], 16) / 255 for i in (0, 2, 4))
        total += n
        hls += n * (max(col) + min(col)) / 2
        px.append((n, *oklch(col)))
    if not total:
        return None
    base = _base(px, total)
    return {"mean_l": round(hls / total, 4), "base": base, "accent": _accent(px, total, base)}


def manual_features(hue_deg, light, sat):
    """The Manual hue editor's HSL hue as features, so the pill matches the swatch the strip shows."""
    h = oklch(colorsys.hls_to_rgb((hue_deg % 360) / 360, 0.5, 0.75))[2]
    chromatic = sat > 0.02
    return {"mean_l": 0.85 if light else 0.12, "base": [h, 0.09] if chromatic else None,
            "accent": [h, 0.15, 0.70] if chromatic else None}


def mix(x, y):
    """Theme.textFaint's channel average of two colours."""
    return "#%02x%02x%02x" % tuple(round((a + b) / 2 * 255) for a, b in zip(rgb(x), rgb(y)))


def _readable(L, C, h, backs, ratio, step):
    while True:
        out = lch(L, C, h)
        if min(contrast(out, b) for b in backs) >= ratio or not 0.0 < L < 1.0:
            return out
        L += step


def palette(feat, light=None, vibrancy=0.5):
    """Pill colours from features, tone and strength (0 muted, 0.5 natural, 1 vivid), contrast-checked on the body."""
    v = clamp(vibrancy)
    light = feat["mean_l"] >= 0.40 if light is None else light
    base, acc = feat.get("base"), feat.get("accent")
    if base:
        bh, bc = base
        cap = (0.010 + 0.050 * v) if light else (0.012 + 0.058 * v)
        sc = min(max(bc * (0.18 + 0.50 * v), 0.004 + 0.014 * v), cap)
    else:
        bh, bc, sc = (acc[0] if acc else 60.0), 0.0, 0.0
    if acc:
        ah, ac, al = acc[0], acc[1] * (1.0 if base else 0.5), acc[2]
    else:
        ah, ac, al = bh, max(bc * 1.5, 0.08) if base else 0.0, None
    if base or acc:
        ac = min(max(ac * (0.45 + 0.75 * v), 0.02 + 0.06 * v), 0.10 + 0.14 * v)
    else:
        ac = 0.012
    m = feat["mean_l"]
    if light:
        sl, steps, text, sign = lerp(m, 0.40, 0.75, 0.950, 0.975), LIGHT_STEPS, LIGHT_TEXT, -1
        acc_l = clamp(0.50 + 0.3 * ((al or 0.6) - 0.6), 0.42, 0.58)
        deep_l, glow_l, outline_d = 0.38, 0.66, -0.40
    else:
        sl, steps, text, sign = lerp(m, 0.0, 0.40, 0.17, 0.25), DARK_STEPS, DARK_TEXT, 1
        acc_l = clamp(0.74 + 0.3 * ((al or 0.7) - 0.7) + 0.09 * clamp(1 - hue_dist(ah, 105) / 45), 0.66, 0.88)
        deep_l, glow_l, outline_d = 0.40, 0.88, 0.30
    p = {name: lch(sl + st, sc * (1.25 if name == "outline_variant" else 1.0), bh)
         for name, st in zip(SURF_NAMES, steps)}
    body = [p["surface"], p["surface_container_low"], p["surface_container_high"]]
    p["primary"] = _readable(acc_l, ac, ah, body, 3.2, sign * 0.01)
    p["primary_container"] = lch(deep_l, ac * 0.8, ah)
    p["on_primary_container"] = lch(glow_l, ac * (0.85 if light else 0.45), ah)
    p["outline"] = lch(sl + outline_d, sc, bh)
    tc = min(0.006 + sc * 0.45, 0.028) if base or acc else 0.0
    for key, lit, need in zip(TEXT_KEYS, text, TEXT_MIN):
        p[key] = _readable(lit, tc * (1.5 if key == "tick_rest" else 1.0), bh, body, need + 0.1, sign * 0.01)
    lit = text[TEXT_KEYS.index("faint")]
    while min(contrast(mix(p["faint"], p["subtle"]), b) for b in body) < 4.6 and 0.0 < lit < 1.0:
        lit += sign * 0.01
        p["faint"] = lch(lit, tc, bh)
    return p


def seed(feat):
    """matugen's source colour for the always-dark terminal base16, from the wallpaper's base family."""
    base = feat.get("base")
    return lch(0.60, clamp(base[1], 0.05, 0.14), base[0]) if base else "#787878"


def analyze(wallpaper):
    out = subprocess.run(
        ["magick", wallpaper, "-alpha", "off", "-resize", "128x128", "-depth", "8",
         "-format", "%c", "histogram:info:-"],
        capture_output=True, text=True).stdout
    return features(out)


def cached_analyze(wallpaper):
    """analyze() remembered per path and mtime, so re-picking a wallpaper skips the magick pass."""
    store = CACHE / "analyze-v2.json"
    mtime = os.stat(wallpaper).st_mtime_ns
    try:
        seen = json.loads(store.read_text())
    except (OSError, ValueError):
        seen = {}
    if not isinstance(seen, dict):
        seen = {}
    hit = seen.get(wallpaper)
    if isinstance(hit, dict) and hit.get("v") == ANALYZE_VERSION and hit.get("mtime") == mtime:
        return hit["features"]
    result = analyze(wallpaper)
    if result:
        seen[wallpaper] = {"v": ANALYZE_VERSION, "mtime": mtime, "features": result}
        CACHE.mkdir(parents=True, exist_ok=True)
        tmp = store.with_name(f".analyze.{os.getpid()}")
        tmp.write_text(json.dumps(seen))
        os.replace(tmp, store)
    return result


def matugen(source_hex):
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


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


def gtk_colors(p):
    named = {
        "accent_bg_color": p["primary"],
        "accent_fg_color": max(p["surface"], p["bright"], key=lambda c: contrast(c, p["primary"])),
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
    colors = gtk_colors(p)
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


def vibrancy():
    try:
        return clamp(float(flags().get("paletteVibrancy", 0.5)))
    except (TypeError, ValueError):
        return 0.5


def publish(pill, source_hex):
    """Write the pill set and fan it out to fastfetch, GTK apps, Hyprland borders and ghostty."""
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / "colors.json").write_text(json.dumps(pill, indent=2) + "\n")
    render_fastfetch(pill)
    if flags().get("appTheme"):
        sync_apps(pill, need_flag=True)

    try:
        b = {k: v["dark"]["color"] for k, v in matugen(source_hex)["base16"].items()}
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return 0

    (CACHE / "hypr-colors.lua").write_text(
        'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
        % (pill["primary"], b["base01"]))
    # Pushed live because hyprctl reload drops game mode and stalls for about a second.
    try:
        subprocess.run(["hyprctl", "eval", 'hl.config({ general = { ["col.active_border"] = "rgb(%s)", '
                        '["col.inactive_border"] = "rgb(%s)" } })' % (pill["primary"][1:], b["base01"][1:])],
                       capture_output=True)
    except OSError:
        pass

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
        light = (sys.argv[3] if len(sys.argv) > 3 else "dark") == "light"
        sat = clamp(float(sys.argv[4]) if len(sys.argv) > 4 else 0.5)
        feat = manual_features(float(sys.argv[2]), light, sat)
        return publish(palette(feat, light, sat), seed(feat))
    wallpaper = sys.argv[1]
    if not Path(wallpaper).is_file():
        return 0
    feat = cached_analyze(wallpaper) or NEUTRAL
    return publish(palette(feat, vibrancy=vibrancy()), seed(feat))


if __name__ == "__main__":
    sys.exit(main())
