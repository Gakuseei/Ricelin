#!/usr/bin/env python3
"""
Ricelin config deploy layer.

Copies the rice into ~/.config, drops an ownership marker so uninstall knows
what is safe to pull, makes the deployed copies portable (neutralize), and
restores the pristine backup on the way out. Every function returns a plan of
actions and only touches the filesystem when apply=True, so a dry run is just
the plan with nothing moved.

install.sh is just the bootstrap that fetches the repo and hands off; this
module owns the real deploy, neutralize, backup and uninstall logic, cleaner and
dry-run friendly.
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

MARKER = ".ricelin-managed"

# Repo root is the parent of this installer/ dir; the deployable configs sit
# under configs/ next to it.
REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIGS = REPO_ROOT / "configs"
CONFIG_ROOT = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))

# The deploy set: (name, source under configs/, dest under ~/.config). The first
# five land as whole dirs; kdeglobals and the session target are single files
# that sit at a different path than their source in the clone.
DEPLOY_SET = [
    ("hypr",       "hypr",                                  "hypr"),
    ("quickshell", "quickshell",                            "quickshell"),
    ("ghostty",    "ghostty",                               "ghostty"),
    ("fish",       "fish",                                  "fish"),
    ("fastfetch",  "fastfetch",                             "fastfetch"),
    ("kdeglobals", "kde/kdeglobals",                        "kdeglobals"),
    ("session",    "systemd/user/hyprland-session.target",  "systemd/user/hyprland-session.target"),
]

# Personal bootloader entries that never deploy. A generic grub-theme installer
# comes later; these three are tied to Erik's disks and machine, so the deploy
# set leaves them out on purpose.
GRUB_EXCLUDED = ["grub/install-torii.sh", "grub/probe-sda4.sh", "grub/10_ricelin"]

# User-owned config files a re-run must never reset: the same protected set the
# update engine three-way merges (hand-mirrored from ricelin-update.py, which
# ships standalone and cannot be imported from here). On a managed re-deploy
# these are carried across the replace instead of reverting to the repo copy,
# so a curl|sh re-run stops undoing Settings (idle timeouts, keybinds, layout).
PRESERVED = [
    "hypr/modules/decoration.lua",
    "hypr/modules/binds.lua",
    "hypr/modules/monitors.lua",
    "hypr/modules/input.lua",
    "hypr/modules/env.lua",
    "hypr/modules/autostart.lua",
    "hypr/modules/animations.lua",
    "hypr/modules/stash-apps.lua",
    "hypr/modules/spaces.lua",
    "hypr/hypridle.conf",
]

# The single auto monitor that replaces a user's hand-tuned layout. Their real
# monitors.lua is kept beside it as monitors.lua.example.
MON_AUTO = """hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
"""

# The portable env, written fresh so a stale nvidia block never rides along.
ENV_BASE = """hl.env("XCURSOR_THEME",   "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("QT_QPA_PLATFORMTHEME", "kde")
"""

# Appended only when an nvidia GPU is on the bus.
ENV_NVIDIA = """
hl.env("LIBVA_DRIVER_NAME",         "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_GSYNC_ALLOWED",        "0")
hl.env("__GL_VRR_ALLOWED",          "0")
"""

# Warm fallback palette for the first fastfetch render, before any wallpaper is
# picked. Matches the baked warm ghostty default. The live wallcolors.py
# overwrites config.jsonc from the wallpaper palette on every change after.
WARM_DEFAULT = {
    "primary": "#e0563b",
    "dim": "#7a6453",
    "on_primary_container": "#f0b85e",
    "surface_container": "#2e231b",
    "surface_container_high": "#3a2c22",
    "subtle": "#b89a86",
    "outline": "#594636",
    "bright": "#fff6f0",
}


def _marker_for(dest, is_dir=None):
    """
    Where the ownership marker lives for a dest. A directory carries it inside,
    a single file gets a sibling named after it (a file cannot hold a marker).
    Pass is_dir for a dest that does not exist yet, else it is read off the path.
    """
    dest = Path(dest)
    if is_dir is None:
        is_dir = dest.is_dir() and not dest.is_symlink()
    return (dest / MARKER) if is_dir else dest.with_name(dest.name + MARKER)


def _is_managed(dest, is_dir=None):
    """True when we deployed this dest, spotted by the marker file."""
    return _marker_for(dest, is_dir).is_file()


def _rm(path):
    """Remove a file, symlink or whole tree if it is there."""
    path = Path(path)
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()


def _copy(src, dest):
    """
    Copy a file or whole tree from the clone into place, keeping modes. Dev cruft
    (the git-tracked test_*.py harnesses and any compiled __pycache__/*.pyc) is
    left behind so it never lands in ~/.config. The live hypridle.conf is skipped
    too: it is untracked (Settings owns it) and only exists in a dev work-tree,
    so deploying from one must behave like deploying from a clean clone, where
    neutralize seeds it from the example.
    """
    src, dest = Path(src), Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(src, dest, ignore=shutil.ignore_patterns(
            "test_*.py", "__pycache__", "*.pyc", "hypridle.conf"))
    else:
        shutil.copy2(src, dest)


def _prune_empty(start, stop):
    """
    Walk up from a removed item's parent dropping any dir deploy created and
    left empty (e.g. systemd/user after the session target goes). Stops at stop
    (the config root, never removed) and at the first dir that still holds
    something. Best-effort: a non-empty dir ends the walk.
    """
    start, stop = Path(start), Path(stop)
    d = start
    while d != stop and stop in d.parents:
        try:
            d.rmdir()
        except OSError:
            break
        d = d.parent


def _has_nvidia():
    """Grep the PCI bus for an nvidia GPU, the same probe install.sh uses."""
    try:
        out = subprocess.run(["lspci"], capture_output=True, text=True).stdout
    except OSError:
        return False
    return "nvidia" in out.lower()


def detect_existing(config_root=CONFIG_ROOT):
    """
    Look at each deploy-set item in ~/.config and report whether it is there
    and, if so, whether Ricelin put it there (carries our marker) or it is a
    foreign config we would back up before replacing. Returns a dict keyed by
    item name with the path, exists, managed and a plain status word.
    """
    config_root = Path(config_root)
    found = {}
    for name, _src_rel, dest_rel in DEPLOY_SET:
        dest = config_root / dest_rel
        is_dir = dest.is_dir() and not dest.is_symlink()
        exists = dest.exists() or dest.is_symlink()
        managed = _is_managed(dest, is_dir) if exists else False
        status = "absent" if not exists else ("managed" if managed else "foreign")
        found[name] = {
            "path": str(dest),
            "exists": exists,
            "managed": managed,
            "status": status,
        }
    return found


def backup(target, apply=True):
    """
    Move a foreign config aside before a deploy takes its place, and return the
    backup path it lands at. The clean <target>.bak is the true first-install
    pristine copy, so it is used only when free; an existing .bak is never
    clobbered, we step to <target>.bak.1, .bak.2 ... for the next free slot, so
    the genuine pristine backup is kept and the current foreign config is still
    saved (never blindly removed). Uninstall later restores from the pristine
    .bak. Returns None only when there is nothing at target to move.
    """
    target = Path(target)
    if not target.exists() and not target.is_symlink():
        return None
    bak = target.with_name(target.name + ".bak")
    n = 1
    while bak.exists() or bak.is_symlink():
        bak = target.with_name(target.name + ".bak.%d" % n)
        n += 1
    if apply:
        shutil.move(str(target), str(bak))
    return str(bak)


def deploy(src=CONFIGS, config_root=CONFIG_ROOT, apply=False):
    """
    Copy every deploy-set item into ~/.config and drop the ownership marker so
    uninstall knows it is ours. A foreign config in the way is always backed up
    before it goes (to .bak, or the next free .bak.N when one is taken), never
    blind-removed; one of our own older copies is replaced cleanly with no
    backup. Returns the action list; nothing moves unless apply is set.
    """
    src = Path(src)
    config_root = Path(config_root)
    actions = []
    for name, src_rel, dest_rel in DEPLOY_SET:
        src_path = src / src_rel
        dest = config_root / dest_rel
        if not src_path.exists():
            actions.append({"item": name, "action": "skip",
                            "reason": "missing in source", "src": str(src_path)})
            continue
        is_dir = src_path.is_dir()
        exists = dest.exists() or dest.is_symlink()
        managed = _is_managed(dest) if exists else False
        bak = backup(dest, apply=False) if (exists and not managed) else None
        keep = [rel for rel in PRESERVED
                if rel.startswith(dest_rel + "/") and (config_root / rel).is_file()] if managed else []
        actions.append({
            "item": name,
            "action": "replace" if managed else "deploy",
            "src": str(src_path),
            "dest": str(dest),
            "backup": bak,
            "managed": managed,
            "preserved": keep,
        })
        if not apply:
            continue
        if managed:
            saved = {rel: (config_root / rel).read_bytes() for rel in keep}
            marker = _marker_for(dest, is_dir)
            if marker.exists():
                marker.unlink()
            _rm(dest)
        else:
            # Foreign config moves aside first, so it is never lost to _rm.
            backup(dest, apply=True)
            saved = {}
        _copy(src_path, dest)
        for rel, data in saved.items():
            (config_root / rel).write_bytes(data)
        _marker_for(dest, is_dir).touch()
    return actions


def _strip_fish(text):
    """
    Make config.fish portable: drop the CachyOS source line and the personal
    grok installer block, keep everything else so the torii greeting stays.
    Returns the cleaned text and a list of what was removed.
    """
    out, removed, in_grok = [], [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("# >>> grok") or s.startswith(">>> grok"):
            in_grok = True
            removed.append("grok block")
            continue
        if in_grok:
            if s.startswith("# <<< grok") or s.startswith("<<< grok"):
                in_grok = False
            continue
        if s.startswith("source /usr/share/cachyos-fish-config"):
            removed.append("cachyos source")
            continue
        out.append(line)
    cleaned = re.sub(r"\n{3,}", "\n\n", "\n".join(out).strip("\n"))
    return (cleaned + "\n" if cleaned else ""), removed


def _seq(hexcol):
    """A #rrggbb hex string as the 'r;g;b' ANSI colour sequence."""
    return "%d;%d;%d" % tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5))


def _fastfetch_palette():
    """
    Pick the palette for the fastfetch render: the live wallpaper colours if a
    cache is already there and every value parses as hex, else the warm default
    so a fresh box (or a corrupt colors.json) still renders instead of aborting
    the whole neutralize.
    """
    cache = Path.home() / ".cache" / "ricelin" / "colors.json"
    if cache.is_file():
        try:
            data = json.loads(cache.read_text())
            if all(k in data for k in WARM_DEFAULT):
                for k in WARM_DEFAULT:
                    _seq(data[k])  # prove every hex parses before trusting it
                return data, "cache"
        except (OSError, ValueError, TypeError):
            pass
    return WARM_DEFAULT, "default"


def _render_fastfetch(ff_dir, palette, apply):
    """
    Stamp the palette into config.jsonc so a fresh terminal shows the torii
    splash before any wallpaper is picked. Same placeholder swap the live
    wallcolors.py does on every wallpaper change, so first render and the rest
    line up. Returns the config.jsonc path, or None when the template is missing.
    """
    tmpl = ff_dir / "config.jsonc.in"
    if not tmpl.is_file():
        return None
    repl = {
        "__LANTERN__": str(ff_dir / "lantern.txt"),
        "__KEYS__": _seq(palette["primary"]),
        "__SEP__": _seq(palette["dim"]),
        "__LOGO1__": _seq(palette["primary"]),
        "__LOGO2__": _seq(palette["on_primary_container"]),
        "__LOGO3__": _seq(palette["surface_container"]),
        "__LOGO4__": _seq(palette["surface_container_high"]),
        "__LOGO5__": _seq(palette["subtle"]),
        "__LOGO6__": _seq(palette["outline"]),
        "__LOGO7__": _seq(palette["bright"]),
    }
    if apply:
        out = tmpl.read_text()
        for key, val in repl.items():
            out = out.replace(key, val)
        (ff_dir / "config.jsonc").write_text(out)
    return str(ff_dir / "config.jsonc")


def _pristine(rel, config_root, src):
    """
    True when the live file is still the byte-exact repo copy, i.e. deploy just
    put it there. A preserved user file (Settings edits, own layout) differs and
    must not be neutralized back to a generic default on a re-run.
    """
    live = Path(config_root) / rel
    source = Path(src) / rel
    return live.is_file() and source.is_file() and live.read_bytes() == source.read_bytes()


def neutralize(config_root=CONFIG_ROOT, apply=False, src=CONFIGS):
    """
    Make the deployed configs portable. Operates in place on what deploy() put
    in ~/.config and returns the action list; nothing is written unless apply.
    The monitors and env rewrites only touch a file that is still the pristine
    repo copy, so a user file preserved across a re-deploy stays as it is.

      monitors.lua -> keep the user's layout as monitors.lua.example, write the
                      single auto monitor (output="", preferred, auto, scale 1)
      env.lua      -> rewrite the base env, keep the nvidia vars only on nvidia
      ghostty      -> rewrite /home/erik to the real home
      ghosttype    -> rewrite /home/erik in the GhostType AppImage bind path so it
                      points at the user's home, not Erik's
      hypridle     -> rewrite /home/erik in the lock_cmd / on-timeout script paths
                      (the conf does not expand env vars, so a literal home is wrong
                      for any other user and idle-lock never fires)
      fish         -> strip the cachyos source line and the grok block, keep the
                      torii greeting
      fastfetch    -> render config.jsonc from the palette so the splash shows
      grub         -> never deployed, recorded here for the record
    """
    config_root = Path(config_root)
    actions = []

    mon = config_root / "hypr" / "modules" / "monitors.lua"
    if _pristine("hypr/modules/monitors.lua", config_root, src):
        example = mon.with_name(mon.name + ".example")
        save_example = not example.exists()
        actions.append({"step": "monitors", "path": str(mon),
                        "example": str(example) if save_example else None,
                        "wrote": "single auto monitor"})
        if apply:
            if save_example:
                shutil.copy2(mon, example)
            mon.write_text(MON_AUTO)

    env = config_root / "hypr" / "modules" / "env.lua"
    if _pristine("hypr/modules/env.lua", config_root, src):
        nvidia = _has_nvidia()
        actions.append({"step": "env", "path": str(env), "nvidia": nvidia,
                        "wrote": "base env" + (" + nvidia" if nvidia else ", nvidia dropped")})
        if apply:
            env.write_text(ENV_BASE + (ENV_NVIDIA if nvidia else ""))

    ghc = config_root / "ghostty" / "config"
    if ghc.is_file():
        home = str(Path.home())
        text = ghc.read_text()
        count = text.count("/home/erik")
        actions.append({"step": "ghostty", "path": str(ghc),
                        "replaced": count, "home": home})
        if apply and count:
            ghc.write_text(text.replace("/home/erik", home))

    ght = config_root / "hypr" / "ghosttype.lua"
    if ght.is_file():
        home = str(Path.home())
        text = ght.read_text()
        count = text.count("/home/erik")
        actions.append({"step": "ghosttype", "path": str(ght),
                        "replaced": count, "home": home})
        if apply and count:
            ght.write_text(text.replace("/home/erik", home))

    # The live hypridle.conf is untracked (Settings owns it, and tracking it made
    # git pulls revert a user's auto-lock choice), so a fresh deploy seeds it from
    # the shipped example once, then the home rewrite runs on whatever is there.
    idle = config_root / "hypr" / "hypridle.conf"
    idle_example = idle.with_name(idle.name + ".example")
    if not idle.is_file() and idle_example.is_file():
        actions.append({"step": "hypridle-seed", "path": str(idle),
                        "wrote": "from hypridle.conf.example"})
        if apply:
            shutil.copy2(idle_example, idle)
    if idle.is_file():
        home = str(Path.home())
        text = idle.read_text()
        count = text.count("/home/erik")
        actions.append({"step": "hypridle", "path": str(idle),
                        "replaced": count, "home": home})
        if apply and count:
            idle.write_text(text.replace("/home/erik", home))

    fish = config_root / "fish" / "config.fish"
    if fish.is_file():
        cleaned, removed = _strip_fish(fish.read_text())
        actions.append({"step": "fish", "path": str(fish), "stripped": removed})
        if apply and removed:
            fish.write_text(cleaned)

    ff = config_root / "fastfetch"
    if (ff / "config.jsonc.in").is_file():
        palette, source = _fastfetch_palette()
        out = _render_fastfetch(ff, palette, apply)
        actions.append({"step": "fastfetch", "path": str(ff / "config.jsonc"),
                        "palette": source, "rendered": out is not None})

    actions.append({"step": "grub-excluded", "files": GRUB_EXCLUDED,
                    "note": "personal bootloader entries, never deployed"})
    return actions


def uninstall(config_root=CONFIG_ROOT, apply=False):
    """
    Remove every Ricelin-managed item from ~/.config and put its pristine .bak
    back. A dest without our marker is the user's own config, left untouched.
    Returns the action list; nothing is removed unless apply is set.
    """
    config_root = Path(config_root)
    actions = []
    for name, _src_rel, dest_rel in DEPLOY_SET:
        dest = config_root / dest_rel
        exists = dest.exists() or dest.is_symlink()
        if not exists:
            continue
        is_dir = dest.is_dir() and not dest.is_symlink()
        if not _is_managed(dest, is_dir):
            actions.append({"item": name, "action": "skip",
                            "reason": "not Ricelin-managed", "dest": str(dest)})
            continue
        bak = dest.with_name(dest.name + ".bak")
        restore = str(bak) if (bak.exists() or bak.is_symlink()) else None
        actions.append({"item": name, "action": "remove",
                        "dest": str(dest), "restored": restore})
        if apply:
            marker = _marker_for(dest, is_dir)
            if marker.exists():
                marker.unlink()
            _rm(dest)
            if restore:
                shutil.move(str(bak), str(dest))
            else:
                _prune_empty(dest.parent, config_root)
    return actions


def _selftest():
    """Dry-run every function against a tempdir, never touching the live config."""
    import tempfile

    passed = 0

    def check(cond, msg):
        nonlocal passed
        if not cond:
            raise AssertionError(msg)
        passed += 1
        print(f"  ok   {msg}")

    print(":: deploy.py selftest (dry-run, tempdir)\n")
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "config"
        root.mkdir()

        # 1. deploy dry-run on an empty root: a plan, no filesystem touched
        plan = deploy(config_root=root, apply=False)
        check(len(plan) == len(DEPLOY_SET), "deploy plan covers the whole set")
        check(all("item" in a and "action" in a for a in plan),
              "every deploy action is well-formed")
        check(all(a["action"] in ("deploy", "replace", "skip") for a in plan),
              "deploy actions use known verbs")
        check(not (root / "hypr").exists() and not (root / "kdeglobals").exists(),
              "deploy dry-run left the filesystem alone")

        # 2. seed a foreign fish config so the backup path gets exercised
        (root / "fish").mkdir()
        (root / "fish" / "config.fish").write_text("# SENTINEL user fish\n")
        plan = deploy(config_root=root, apply=False)
        fish_act = next(a for a in plan if a["item"] == "fish")
        check(fish_act["backup"] == str(root / "fish.bak"),
              "foreign fish is planned for backup -> fish.bak")

        # 3. deploy for real: foreign fish backed up, fresh copies marked ours
        deploy(config_root=root, apply=True)
        check((root / "fish.bak" / "config.fish").read_text().strip().endswith("user fish"),
              "foreign fish moved aside to fish.bak intact")
        seen = detect_existing(root)
        check(all(v["status"] == "managed" for v in seen.values()),
              "detect_existing sees every item as managed after deploy")

        # deploy leaves dev cruft behind: no tracked test harness, no pycache
        scripts = root / "hypr" / "scripts"
        check(not list(scripts.glob("test_*.py"))
              and not (scripts / "__pycache__").exists(),
              "deploy excluded test_*.py and __pycache__")

        # 4. re-deploy is idempotent: managed -> replace, pristine .bak untouched
        plan = deploy(config_root=root, apply=True)
        check(next(a for a in plan if a["item"] == "fish")["action"] == "replace",
              "re-deploy replaces our own copy (no second backup)")
        check((root / "fish.bak" / "config.fish").read_text().strip().endswith("user fish"),
              "pristine fish.bak never clobbered on re-deploy")

        # 5. neutralize dry-run: a plan with the expected steps, nothing written.
        # hypridle.conf is untracked, so on a fresh deploy only the seed step
        # shows; the rewrite step appears once the file exists.
        plan = neutralize(config_root=root, apply=False)
        steps = {a["step"] for a in plan}
        check({"monitors", "env", "ghostty", "hypridle-seed", "fish", "fastfetch", "grub-excluded"} <= steps,
              "neutralize plan has every step")
        check(not (root / "hypr" / "hypridle.conf").exists(),
              "neutralize dry-run did not seed hypridle.conf")
        check("DP-1" in (root / "hypr" / "modules" / "monitors.lua").read_text(),
              "neutralize dry-run did not rewrite monitors.lua")

        # 6. neutralize for real: each config is made portable
        nvidia = _has_nvidia()
        neutralize(config_root=root, apply=True)
        mon = root / "hypr" / "modules" / "monitors.lua"
        check(mon.read_text() == MON_AUTO, "monitors.lua is now the single auto monitor")
        check((root / "hypr" / "modules" / "monitors.lua.example").read_text().find("DP-1") >= 0,
              "user's monitors layout saved as monitors.lua.example")
        env_txt = (root / "hypr" / "modules" / "env.lua").read_text()
        check(env_txt == ENV_BASE + (ENV_NVIDIA if nvidia else ""),
              f"env.lua matches base{' + nvidia' if nvidia else ' (nvidia dropped)'}")
        gh = (root / "ghostty" / "config").read_text()
        check("?~/.cache/ricelin/ghostty-colors" in gh,
              "ghostty config-file uses the home-relative colors include")
        idletxt = (root / "hypr" / "hypridle.conf").read_text()
        check(str(Path.home()) + "/.config/hypr/scripts/lock.sh" in idletxt,
              "hypridle lock_cmd points at the real home")
        ghttxt = (root / "hypr" / "ghosttype.lua").read_text()
        check(str(Path.home()) + "/Applications/GhostType.AppImage" in ghttxt,
              "ghosttype.lua AppImage path points at the real home")
        fishtxt = (root / "fish" / "config.fish").read_text()
        check("cachyos-fish-config" not in fishtxt and "grok" not in fishtxt
              and "torii-greeting" in fishtxt,
              "fish stripped of cachyos + grok, torii greeting kept")
        ffjson = (root / "fastfetch" / "config.jsonc").read_text()
        check("__" not in ffjson and "system" in ffjson,
              "fastfetch config.jsonc rendered, no placeholders left")

        # 7. uninstall: managed items removed, pristine backup restored
        plan = uninstall(config_root=root, apply=False)
        check(len(plan) >= len(DEPLOY_SET) and all(a["action"] in ("remove", "skip") for a in plan),
              "uninstall plan lists the managed removals")
        uninstall(config_root=root, apply=True)
        check((root / "fish" / "config.fish").read_text().strip().endswith("user fish"),
              "uninstall restored the pristine fish from fish.bak")
        check(not (root / "kdeglobals").exists(),
              "uninstall removed a managed item with no backup")
        check(not (root / "systemd").exists(),
              "uninstall pruned the empty systemd/user dirs it created")

    # 8. backup() numbering, in isolation: free .bak used, taken one steps to .bak.N
    with tempfile.TemporaryDirectory() as tmp2:
        d = Path(tmp2)
        (d / "y").write_text("fresh")
        bak = backup(d / "y")
        check(bak == str(d / "y.bak") and not (d / "y").exists()
              and (d / "y.bak").read_text() == "fresh",
              "backup moves a fresh target to .bak")
        (d / "x").write_text("foreign")
        (d / "x.bak").write_text("pristine")
        bak = backup(d / "x")
        check(bak == str(d / "x.bak.1") and not (d / "x").exists()
              and (d / "x.bak").read_text() == "pristine"
              and (d / "x.bak.1").read_text() == "foreign",
              "backup keeps the pristine .bak, parks the foreign config in .bak.1")

    # 9. data-loss guard (FIX): a foreign config plus a pre-existing .bak must
    # never be lost. deploy parks the foreign config in the next free .bak.N and
    # leaves the genuine pristine .bak alone.
    with tempfile.TemporaryDirectory() as tmp3:
        root = Path(tmp3) / "config"
        (root / "ghostty").mkdir(parents=True)
        (root / "ghostty" / "config").write_text("# FOREIGN ghostty\n")
        (root / "ghostty.bak").mkdir()
        (root / "ghostty.bak" / "config").write_text("# PRISTINE ghostty\n")
        gh_act = next(a for a in deploy(config_root=root, apply=False)
                      if a["item"] == "ghostty")
        check(gh_act["backup"] == str(root / "ghostty.bak.1"),
              "foreign ghostty with a taken .bak plans backup -> ghostty.bak.1")
        deploy(config_root=root, apply=True)
        check((root / "ghostty.bak.1" / "config").read_text().strip().endswith("FOREIGN ghostty"),
              "foreign ghostty preserved in ghostty.bak.1 (no data loss)")
        check((root / "ghostty.bak" / "config").read_text().strip().endswith("PRISTINE ghostty"),
              "genuine pristine ghostty.bak left untouched")
        check(_is_managed(root / "ghostty"),
              "fresh managed ghostty deployed in place")

    # 10. re-run guard (FIX #17): a full second install pass (deploy + neutralize)
    # must not reset user-owned config. Settings-written hypridle.conf and a
    # hand-tuned monitors.lua have to survive byte-exact.
    with tempfile.TemporaryDirectory() as tmp4:
        root = Path(tmp4) / "config"
        root.mkdir()
        deploy(config_root=root, apply=True)
        neutralize(config_root=root, apply=True)
        idle_off = "general {\n    lock_cmd = /home/testuser/lock.sh\n}\n"
        mon_user = "hl.monitor({ output = \"HDMI-A-1\", mode = \"preferred\" })\n"
        (root / "hypr" / "hypridle.conf").write_text(idle_off)
        (root / "hypr" / "modules" / "monitors.lua").write_text(mon_user)
        plan = deploy(config_root=root, apply=True)
        hypr_act = next(a for a in plan if a["item"] == "hypr")
        check("hypr/hypridle.conf" in hypr_act["preserved"]
              and "hypr/modules/monitors.lua" in hypr_act["preserved"],
              "re-deploy plans to carry the user files across the replace")
        check((root / "hypr" / "hypridle.conf").read_text() == idle_off,
              "user hypridle.conf survived the re-deploy (lock stays off)")
        neutralize(config_root=root, apply=True)
        check((root / "hypr" / "hypridle.conf").read_text() == idle_off,
              "second neutralize left the user hypridle.conf alone")
        check((root / "hypr" / "modules" / "monitors.lua").read_text() == mon_user,
              "user monitors.lua survived re-deploy + neutralize")
        check((root / "hypr" / "scripts" / "lock.sh").exists(),
              "non-protected code files still refreshed on re-deploy")

    # 11. drift guard: PRESERVED is a hand mirror of the update engine's PROTECTED
    # (the engine ships standalone and can't be imported at runtime). Adding a
    # protected file to one list but not the other silently splits the two update
    # paths, so the selftest holds them byte-equal.
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "_ricelin_update", REPO_ROOT / "configs" / "hypr" / "scripts" / "ricelin-update.py")
    engine = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(engine)
    check(PRESERVED == engine.PROTECTED,
          "PRESERVED matches the update engine's PROTECTED list")

    print(f"\n:: all {passed} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(_selftest())
