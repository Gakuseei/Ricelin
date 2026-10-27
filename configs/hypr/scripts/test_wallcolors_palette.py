#!/usr/bin/env python3
"""Self-test for the pure wallcolors palette: contrast floors, tone, distinct accents, neutral and manual sets."""
import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wallcolors as w  # noqa: E402

KEYS = {"surface", "surface_container_low", "surface_container", "surface_container_high",
        "surface_container_highest", "outline_variant", "primary", "primary_container",
        "on_primary_container", "outline", "cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"}
FLOORS = {"cream": 4.5, "bright": 4.5, "subtle": 4.5, "icon_dim": 4.5, "dim": 3.0, "tick_rest": 3.0, "primary": 3.0}


def hist(*parts):
    return "\n".join(f"  {n}: ({r},{g},{b}) #{r:02X}{g:02X}{b:02X} srgb({r},{g},{b})" for n, (r, g, b) in parts)


def worst(p, key):
    return min(w.contrast(p[key], p[b]) for b in ("surface", "surface_container_low", "surface_container_high"))


def check(p, light):
    assert set(p) == KEYS, "colors.json keys unchanged"
    for key, need in FLOORS.items():
        assert worst(p, key) >= need, f"{key} {worst(p, key):.2f} < {need}"
    assert min(w.contrast(w.mix(p["faint"], p["subtle"]), p[b])
               for b in ("surface", "surface_container_low", "surface_container_high")) >= 4.5, "textFaint readable"
    body = w.oklch(w.rgb(p["surface_container_high"]))[0]
    assert body > 0.85 if light else body < 0.35, f"tone {'light' if light else 'dark'} body L {body:.2f}"


def main():
    n = 0
    for hue, bc, acc, mean_l, tone, v in itertools.product(
            range(0, 360, 30), (0.02, 0.08, 0.16), ("same", "far", None), (0.02, 0.3, 0.6),
            (None, True, False), (0.0, 0.5, 1.0)):
        accent = {"same": [hue, bc * 1.4, 0.6], "far": [(hue + 160) % 360, 0.15, 0.75], None: None}[acc]
        feat = {"mean_l": mean_l, "base": [hue, bc], "accent": accent}
        check(w.palette(feat, tone, v), mean_l >= 0.40 if tone is None else tone)
        n += 1
    print(f"A contrast and tone over {n} palettes: ok")

    sky = (700, (70, 120, 200))
    orange = w.features(hist(sky, (200, (30, 40, 60)), (50, (240, 140, 50))))
    pink = w.features(hist(sky, (200, (30, 40, 60)), (50, (235, 110, 190))))
    assert w.hue_dist(orange["base"][0], pink["base"][0]) < 5, "same dominant hue"
    assert w.hue_dist(orange["accent"][0], pink["accent"][0]) > 40, "different highlights, different accents"
    assert w.palette(orange)["primary"] != w.palette(pink)["primary"]
    print("B distinct highlights: ok")

    grey = w.features(hist((600, (20, 20, 20)), (300, (90, 90, 90)), (100, (200, 200, 200))))
    assert grey["base"] is None and grey["accent"] is None, "grey wallpaper is achromatic"
    for tone in (False, True):
        p = w.palette(grey, tone)
        check(p, tone)
        assert all(max(w.rgb(p[k])) - min(w.rgb(p[k])) < 0.02 for k in w.SURF_NAMES), "neutral ramp"
    print("C neutral: ok")

    for hue, tone, sat in itertools.product(range(0, 360, 15), (False, True), (0.0, 0.25, 0.5, 1.0)):
        check(w.palette(w.manual_features(hue, tone, sat), tone, sat), tone)
    red = w.manual_features(0, False, 0.5)["accent"][0]
    assert w.hue_dist(red, 29) < 5, "manual hue follows the HSL strip"
    print("D manual: ok")

    feat = {"mean_l": 0.2, "base": [250, 0.1], "accent": [40, 0.15, 0.7]}
    chroma = [w.oklch(w.rgb(w.palette(feat, vibrancy=v)["primary"]))[1] for v in (0.0, 0.5, 1.0)]
    assert chroma[0] < chroma[1] < chroma[2], "vibrancy raises accent chroma"
    print("E vibrancy: ok")
    print("\nALL TESTS PASSED")


if __name__ == "__main__":
    main()
