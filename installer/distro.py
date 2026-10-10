#!/usr/bin/env python3
"""
Distro detection and package-name resolution for the Ricelin installer. This is
the contract the rest of the installer builds on: it turns a manifest entry plus
the detected distro family into a concrete action, either install a native
package, run a fallback handler, or skip because another package already
provides it. Pure logic, no installing, so it is cheap to unit-test anywhere.
"""
import json
import os

FAMILIES = ("arch", "debian", "fedora", "suse", "gentoo")

# The privilege wrapper every root step goes through. sudo by default, doas when
# the user picks it in the wizard; read at call time, never at import.
ROOT = "sudo"

# os-release ID / ID_LIKE tokens that map onto each family. The real safety net is
# the ID_LIKE=arch token, which catches any respin that sets it regardless of this
# list. The explicit names below exist for the members that ship NO ID_LIKE at all
# (arch, artix, athena, blackarch, crystal, snigdha, archbang), plus a generous set
# of active respins as belt-and-suspenders. IDs are lowercased before matching,
# which also catches a capitalised ID like Snigdha.
_FAMILY_TOKENS = {
    "arch": ("arch", "cachyos", "endeavouros", "manjaro", "garuda", "artix",
             "arcolinux", "archcraft", "rebornos", "athena", "blackarch", "archbang",
             "crystal", "snigdha", "parabola", "obarun", "arch32", "hyperbola", "steamos",
             "omarchy", "xerolinux", "archman", "biglinux", "ctlos", "tromjaro",
             "bluestar", "arkane", "blendos", "acreetionos", "mabox"),
    "debian": ("debian", "ubuntu", "linuxmint", "pop", "elementary", "zorin", "raspbian"),
    "fedora": ("fedora", "nobara", "rhel", "centos", "rocky", "almalinux"),
    "suse": ("suse", "opensuse", "sles", "sled", "tumbleweed", "leap"),
    "gentoo": ("gentoo", "funtoo", "calculate", "pentoo", "redcore"),
}

# Distros with a read-only root, where the file deploy must stay under $HOME and
# the system tree is wiped on the next update.
_IMMUTABLE = {"steamos"}

# package manager per family.
PM = {"arch": "pacman", "debian": "apt-get", "fedora": "dnf", "suse": "zypper",
      "gentoo": "emerge"}


def _default_manifest_path():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "packages.json")


def load_manifest(path=None):
    with open(path or _default_manifest_path()) as fh:
        return json.load(fh)


def _os_release(path="/etc/os-release"):
    data = {}
    try:
        with open(path) as fh:
            for line in fh:
                if "=" in line and not line.startswith("#"):
                    k, v = line.rstrip().split("=", 1)
                    data[k] = v.strip().strip('"\'')
    except OSError:
        pass
    return data


def family_from_os_release(data):
    """Map os-release ID and ID_LIKE onto a family, ID first then ID_LIKE."""
    ids = [data.get("ID", "").lower()]
    ids += data.get("ID_LIKE", "").lower().split()
    for token in ids:
        for fam, names in _FAMILY_TOKENS.items():
            if token in names:
                return fam
    return "unknown"


def detect_family(os_release_path="/etc/os-release"):
    return family_from_os_release(_os_release(os_release_path))


def detect_pretty(os_release_path="/etc/os-release"):
    data = _os_release(os_release_path)
    return data.get("PRETTY_NAME") or data.get("NAME") or "unknown"


def detect_init():
    """
    The init system actually running, so the service step never blindly calls
    systemctl. The live check wins over the os-release ID, since some Arch
    respins (Parabola) ship both a systemd and a non-systemd edition.
    """
    if os.path.isdir("/run/systemd/system"):
        return "systemd"
    for marker, name in (("/run/openrc", "openrc"), ("/run/runit", "runit"),
                         ("/run/s6-rc", "s6"), ("/run/dinit", "dinit")):
        if os.path.exists(marker):
            return name
    return "unknown"


def is_immutable(os_release_path="/etc/os-release"):
    """
    True for a read-only-root distro like SteamOS, where the deploy must target
    $HOME and the system tree can be wiped on the next atomic update.
    """
    return _os_release(os_release_path).get("ID", "").lower() in _IMMUTABLE


def native_name(pkg, family):
    """The native package name on this family, or None when there is none."""
    return (pkg.get("names") or {}).get(family)


def is_aur(pkg, family):
    """An Arch AUR package that needs a helper, only ever true on the arch family."""
    return family == "arch" and bool(pkg.get("aur")) and native_name(pkg, family) is not None


def repo_for(pkg, family):
    """An extra repo to enable first (copr: on Fedora, obs: on openSUSE, overlay: on Gentoo)."""
    return (pkg.get("repo") or {}).get(family)


def resolve(pkg, family, aur_choice="yay"):
    """
    Decide what to do with one package on one family:
      ("native", name)        install this package with the family's manager
      ("fallback", handlerId) no native package, hand off to the named handler
      ("skip", None)          another package already provides it here

    aur_choice is the user's AUR-helper pick. When it is "none" an Arch AUR
    package the user opted out of building gets rerouted to its fallback handler
    instead, so the AUR is never touched without a helper to drive it.
    """
    if (family == "arch" and is_aur(pkg, family)
            and aur_choice == "none" and pkg.get("fallback")):
        return ("fallback", pkg["fallback"])
    name = native_name(pkg, family)
    if name:
        return ("native", name)
    if pkg.get("fallback"):
        return ("fallback", pkg["fallback"])
    return ("skip", None)


def plan(manifest, family, groups=("core",), aur_choice="yay"):
    """
    Resolve every package in the chosen groups into an ordered action list. Each
    row carries the package, the action, and the repo to enable so the caller can
    batch native installs and run fallbacks one by one. aur_choice flows down to
    resolve so the "none" helper option reroutes AUR packages to their fallback.
    """
    rows = []
    for pkg in manifest["packages"]:
        if pkg.get("group") not in groups:
            continue
        action, target = resolve(pkg, family, aur_choice)
        rows.append({
            "id": pkg["id"],
            "action": action,
            "target": target,
            "aur": is_aur(pkg, family),
            "repo": repo_for(pkg, family),
            "desc": pkg.get("desc", ""),
            "required": pkg.get("required", False),
            "group": pkg.get("group"),
        })
    return rows


def _selftest():
    m = load_manifest()
    by_id = {p["id"]: p for p in m["packages"]}

    # family detection from a synthetic os-release
    assert family_from_os_release({"ID": "cachyos", "ID_LIKE": "arch"}) == "arch"
    assert family_from_os_release({"ID": "ubuntu", "ID_LIKE": "debian"}) == "debian"
    assert family_from_os_release({"ID": "fedora"}) == "fedora"
    assert family_from_os_release({"ID": "opensuse-tumbleweed", "ID_LIKE": "suse opensuse"}) == "suse"
    assert family_from_os_release({"ID": "void"}) == "unknown"
    assert family_from_os_release({"ID": "gentoo"}) == "gentoo"
    import tempfile
    fd, osr = tempfile.mkstemp(); os.write(fd, b"NAME='Gentoo'\nID='gentoo'\n"); os.close(fd)
    assert _os_release(osr) == {"NAME": "Gentoo", "ID": "gentoo"}, "single-quoted os-release (Gentoo)"
    os.unlink(osr)
    assert family_from_os_release({"ID": "funtoo", "ID_LIKE": "gentoo"}) == "gentoo"
    assert family_from_os_release({"ID": "artix"}) == "arch"
    assert family_from_os_release({"ID": "Snigdha"}) == "arch"
    assert family_from_os_release({"ID": "steamos", "ID_LIKE": "arch"}) == "arch"
    assert detect_init() == "systemd"
    assert "steamos" in _IMMUTABLE

    # name mapping
    assert native_name(by_id["imagemagick"], "fedora") == "ImageMagick"
    assert native_name(by_id["imagemagick"], "debian") == "imagemagick"
    assert native_name(by_id["networkmanager"], "debian") == "network-manager"
    assert native_name(by_id["networkmanager"], "fedora") == "NetworkManager"
    assert native_name(by_id["noto-fonts"], "fedora") == "google-noto-sans-fonts"
    assert native_name(by_id["kde-cli-tools"], "suse") == "kde-cli-tools6"
    assert native_name(by_id["swww"], "gentoo") == "gui-apps/awww"
    assert native_name(by_id["hyprpolkitagent"], "gentoo") == "sys-auth/hyprpolkitagent"

    # resolve rule
    assert resolve(by_id["bluez-utils"], "debian") == ("skip", None)
    assert resolve(by_id["bluez-utils"], "arch") == ("native", "bluez-utils")
    assert resolve(by_id["ghostty"], "debian") == ("fallback", "ghostty")
    assert resolve(by_id["ghostty"], "suse") == ("native", "ghostty")
    assert resolve(by_id["dotool"], "fedora") == ("fallback", "dotool")
    assert resolve(by_id["dotool"], "arch") == ("native", "dotool")
    assert resolve(by_id["dotool"], "gentoo") == ("native", "x11-misc/dotool")
    assert resolve(by_id["ttf-jetbrains-mono-nerd"], "gentoo") == ("fallback", "nerdfont")
    assert resolve(by_id["bibata-cursor-theme"], "gentoo") == ("fallback", "github")
    assert resolve(by_id["bluez-utils"], "gentoo") == ("skip", None)

    # aur_choice "none" reroutes an Arch AUR package to its fallback, "yay" keeps it native
    assert resolve(by_id["dotool"], "arch", aur_choice="none") == ("fallback", "dotool")
    assert resolve(by_id["dotool"], "arch", aur_choice="yay") == ("native", "dotool")

    # aur only on arch, only for aur packages
    assert is_aur(by_id["dotool"], "arch") is True
    assert is_aur(by_id["dotool"], "debian") is False
    assert is_aur(by_id["cava"], "arch") is False

    # repos
    assert repo_for(by_id["hyprland"], "fedora") == "copr:solopasha/hyprland"
    assert repo_for(by_id["quickshell"], "suse") == "obs:home:AvengeMedia:danklinux"
    assert repo_for(by_id["quickshell"], "fedora") == "copr:errornointernet/quickshell"
    assert repo_for(by_id["quickshell"], "debian") == "ppa:avengemedia/danklinux"
    assert repo_for(by_id["hyprland"], "arch") is None
    assert repo_for(by_id["hyprland"], "gentoo") == "overlay:hyproverlay"
    assert repo_for(by_id["quickshell"], "gentoo") == "overlay:guru"
    assert repo_for(by_id["cava"], "gentoo") is None

    # plan covers core, skips full, marks fallbacks
    core = plan(m, "debian", groups=("core",))
    ids = {r["id"] for r in core}
    assert "ghostty" in ids and "dolphin" not in ids
    ghostty = next(r for r in core if r["id"] == "ghostty")
    assert ghostty["action"] == "fallback" and ghostty["target"] == "ghostty"

    _check_token_mirrors()

    print("distro.py selftest: all checks passed")
    print("detected here:", detect_pretty(), "->", detect_family())


def _check_token_mirrors():
    """
    The family tokens are hand-mirrored into install.sh (shell can't import this
    module) and ricelin-update.py (ships standalone on user boxes). Nothing at
    runtime can enforce the copies, so the selftest does: parse both files and
    fail loud the moment one drifts.
    """
    import importlib.util
    import re

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    sh = open(os.path.join(root, "install.sh")).read()
    for fam, var in (("arch", "ARCH_IDS"), ("debian", "DEBIAN_IDS"),
                     ("fedora", "FEDORA_IDS"), ("suse", "SUSE_IDS"),
                     ("gentoo", "GENTOO_IDS")):
        m = re.search(var + r'="([^"]*)"', sh)
        assert m, f"{var} missing from install.sh"
        assert set(m.group(1).split()) == set(_FAMILY_TOKENS[fam]), \
            f"install.sh {var} drifted from _FAMILY_TOKENS[{fam!r}]"

    engine_path = os.path.join(root, "configs", "hypr", "scripts", "ricelin-update.py")
    spec = importlib.util.spec_from_file_location("_ricelin_update", engine_path)
    engine = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(engine)
    for fam in _FAMILY_TOKENS:
        assert set(engine.FAMILY_TOKENS[fam]) == set(_FAMILY_TOKENS[fam]), \
            f"engine FAMILY_TOKENS[{fam!r}] drifted from distro.py"


if __name__ == "__main__":
    _selftest()
