#!/usr/bin/env python3
"""
Package-manager operations for the Ricelin multi-distro installer. distro.py
decides what to do with each package (native, fallback, skip); this module turns
those decisions into the concrete shell argv that actually queries or installs a
package on the detected family. Building argv lists instead of running them keeps
the policy here and the running (terminal echo, sudo prompt, error handling) in
the caller, so fallbacks.py and the in-app updater share one source of truth for
how every distro is driven. The one place that does touch the system is
is_installed, a read-only DB query.
"""
import os
import re
import shlex
import shutil
import subprocess
import tempfile

import distro


# Environment overrides the runner merges in for the apt path, so a package that
# pops a debconf prompt mid-install can never wedge the unattended terminal run.
INSTALL_ENV = {"DEBIAN_FRONTEND": "noninteractive"}


def _require_family(family):
    """Guard against a family distro.PM never mapped, so a typo fails loud."""
    if family not in distro.PM:
        raise ValueError(f"unknown family {family!r}, expected one of {tuple(distro.PM)}")


def is_installed(name, family):
    """
    Ask the native package DB whether name is installed, read-only and quiet. A
    missing package is a normal answer, not an error, so any failure to even run
    the query (wrong tool, no DB) returns False rather than raising.
    """
    _require_family(family)
    try:
        if family == "arch":
            r = subprocess.run(["pacman", "-Qq", name], capture_output=True, text=True)
            return r.returncode == 0
        if family == "debian":
            r = subprocess.run(["dpkg-query", "-W", "-f=${Status}", name],
                               capture_output=True, text=True)
            return "install ok installed" in r.stdout
        if family == "gentoo":
            r = subprocess.run(["portageq", "has_version", "/", name], capture_output=True)
            return r.returncode == 0
        # fedora and suse are both rpm underneath; rpm -q is the reliable check.
        r = subprocess.run(["rpm", "-q", name], capture_output=True, text=True)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def aur_helper():
    """The AUR helper on PATH, yay preferred over paru, or None when neither is."""
    for helper in ("yay", "paru"):
        if shutil.which(helper):
            return helper
    return None


def install_argv(names, family, aur=False):
    """
    The install command for these package names on this family. aur=True switches
    Arch onto the user's AUR helper instead of pacman; the caller must have run
    ensure_aur_helper_steps first, so a missing helper here is a hard error rather
    than a None silently dropped into the argv.
    """
    _require_family(family)
    if family == "arch":
        if aur:
            helper = aur_helper()
            if helper is None:
                raise RuntimeError("no AUR helper on PATH, run ensure_aur_helper_steps first")
            return [helper, "-S", "--needed", "--noconfirm", *names]
        return ["pacman", "-S", "--needed", "--noconfirm", *names]
    if family == "debian":
        return ["apt-get", "install", "-y", *names]
    if family == "fedora":
        return ["dnf", "install", "-y", *names]
    if family == "gentoo":
        return ["emerge", "--noreplace", *names]
    return ["zypper", "--non-interactive", "install", *names]


def _version_id(os_release_path="/etc/os-release"):
    """The os-release VERSION_ID (e.g. 15.6 on Leap), or "" when unset, as on Tumbleweed."""
    return distro._os_release(os_release_path).get("VERSION_ID", "")


def _obs_build_target(os_release_path="/etc/os-release"):
    """
    The OBS build-target folder for the running openSUSE edition. Leap publishes
    per release under openSUSE_Leap_$VERSION_ID; Tumbleweed (and anything that
    does not look like Leap) rolls into the single openSUSE_Tumbleweed folder. A
    Leap is spotted by a 'leap' ID or a dotted NN.N VERSION_ID, since Tumbleweed
    stamps a bare date there.
    """
    data = distro._os_release(os_release_path)
    ident = data.get("ID", "").lower()
    version = _version_id(os_release_path)
    if "leap" in ident or re.match(r"^\d+\.\d+$", version):
        return f"openSUSE_Leap_{version}"
    return "openSUSE_Tumbleweed"


def _ubuntu_like(os_release_path="/etc/os-release"):
    """
    True when the box is Ubuntu or an Ubuntu derivative, read off ID and ID_LIKE.
    A Launchpad PPA only serves Ubuntu series, so plain Debian must never get one
    added; there add-apt-repository would write a source with no matching release.
    """
    data = distro._os_release(os_release_path)
    ids = [data.get("ID", "").lower()] + data.get("ID_LIKE", "").lower().split()
    return "ubuntu" in ids


def enable_repo_argv(repo, family):
    """
    Turn a manifest repo string into the ordered argv steps that enable it. Always
    a list of argvs so the caller runs them with one loop: copr first pulls the
    dnf plugin that ships the copr subcommand (absent on a minimal Fedora) then
    enables the repo; obs adds the repo then refreshes to import its signing key;
    ppa applies only on an Ubuntu-like box and returns [] on plain Debian, where
    the package must come from the distro's own archive instead; overlay pulls
    eselect-repository, enables the overlay unless portage already knows it
    (eselect exits 1 on a repeat enable, which would read as a failed step on
    every re-run), then syncs just that one overlay.

    The copr subcommand lives in a different package across the dnf split:
    dnf-plugins-core on dnf4 (Fedora <=40) and dnf5-plugins on dnf5 (Fedora 41+).
    A single `dnf install dnf-plugins-core dnf5-plugins` would abort on whichever
    name this release does not carry, so both are installed best-effort in one
    shell (errors swallowed, trailing `true`) and the absent one is simply skipped.

    The OBS download URL for project home:AvengeMedia:danklinux is
    https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/<target>/
    i.e. each ':' in the project path becomes ':/' and <target> is the build
    target for this edition (Tumbleweed or openSUSE_Leap_$VERSION_ID, see
    _obs_build_target). The repo alias is the same path with ':' turned to '_'.
    """
    if repo.startswith("copr:") and family == "fedora":
        owner_name = repo[len("copr:"):]
        return [
            ["sh", "-c",
             "dnf install -y dnf-plugins-core 2>/dev/null; "
             "dnf install -y dnf5-plugins 2>/dev/null; true"],
            ["dnf", "copr", "enable", "-y", owner_name],
        ]
    if repo.startswith("ppa:") and family == "debian":
        if not _ubuntu_like():
            return []
        return [
            ["apt-get", "install", "-y", "software-properties-common"],
            ["add-apt-repository", "-y", repo],
            ["apt-get", "update"],
        ]
    if repo.startswith("overlay:") and family == "gentoo":
        name = repo[len("overlay:"):]
        return [
            ["emerge", "--noreplace", "app-eselect/eselect-repository"],
            ["sh", "-c", f"portageq get_repo_path / {name} >/dev/null 2>&1 || "
                         f"eselect repository enable {name}"],
            ["emerge", "--sync", name],
        ]
    if repo.startswith("obs:") and family == "suse":
        project = repo[len("obs:"):]
        url = (f"https://download.opensuse.org/repositories/"
               f"{project.replace(':', ':/')}/{_obs_build_target()}/")
        alias = project.replace(":", "_")
        return [
            ["zypper", "--non-interactive", "addrepo", url, alias],
            ["zypper", "--non-interactive", "--gpg-auto-import-keys", "refresh"],
        ]
    raise ValueError(f"cannot enable repo {repo!r} on family {family!r}")


def refresh_argv(family):
    """
    The package-list refresh command for this family, run once before any installs
    so a stale index never sinks the first install. pacman folds the refresh into
    -Sy; the rpm and apt families have a dedicated metadata step; emerge syncs the
    ebuild tree, which on a fresh box also pulls it the first time.
    """
    _require_family(family)
    if family == "arch":
        return [distro.ROOT, "pacman", "-Sy"]
    if family == "debian":
        return [distro.ROOT, "apt-get", "update"]
    if family == "fedora":
        return [distro.ROOT, "dnf", "makecache"]
    if family == "gentoo":
        return [distro.ROOT, "emerge", "--sync"]
    return [distro.ROOT, "zypper", "--non-interactive", "refresh"]


# Gentoo portage overrides the rice needs, written to files named ricelin under
# /etc/portage so nothing of the user's own config is ever edited and uninstall
# can remove them by name. Keywords stay per atom: the whole GURU overlay would
# unmask thousands of packages, and a ~amd64 line on a stable main-tree package
# would silently pull its testing version. hyproverlay is the one exception, the
# Gentoo wiki's own recipe, since every one of its ebuilds is ~amd64 and hyprland
# drags a dozen of them in as deps (hyprutils, aquamarine, hyprlang, ...).
# GENTOO_DEPS holds what one atom (or overlay) pulls in beyond itself: the wayland
# trio the hypr tip builds against, the testing sdbus-c++ behind hypridle, the USE
# flags a dep wants. Found by resolving the whole set on a stage3 with emerge -pv.
PORTAGE_DIR = "/etc/portage"
GENTOO_TESTING = ("app-shells/zoxide", "app-admin/keepassxc")
GENTOO_DEPS = {
    "overlay:hyproverlay": {"keywords": ["*/*::hyproverlay", "dev-libs/wayland",
                                         "dev-libs/wayland-protocols", "dev-util/wayland-scanner"]},
    "gui-wm/hyprland": {"use": ["gui-wm/hyprland LUA_SINGLE_TARGET: lua5-4"]},
    "gui-apps/hypridle": {"keywords": ["dev-cpp/sdbus-c++"]},
    "gui-apps/quickshell": {"use": ["gui-apps/quickshell -crash-handler"]},
    "media-sound/cava": {"use": ["media-sound/cava pipewire"]},
    "x11-terms/ghostty": {"use": ["x11-terms/ghostty wayland"]},
    "app-admin/keepassxc": {"use": ["sys-libs/zlib minizip"]},
}


def portage_lines(atom_repos):
    """
    The keyword and USE lines for the atoms about to install, given as a dict of
    atom to its overlay (None for the main tree). Each list is ready to write.
    """
    keywords, use = [], []
    for trigger in [*sorted(set(atom_repos.values()) - {None}), *atom_repos]:
        extra = GENTOO_DEPS.get(trigger, {})
        keywords += extra.get("keywords", [])
        use += extra.get("use", [])
    keywords += [a for a, repo in atom_repos.items()
                 if a in GENTOO_TESTING or repo == "overlay:guru"]
    return [f"{k} ~amd64" for k in keywords], use


def portage_config_argv(atom_repos):
    """
    The privileged steps that write the two ricelin override files. mkdir -p fails
    loud on an old box where package.accept_keywords is still a single file, which
    is the right outcome: converting the user's file is not this installer's call.
    """
    keywords, use = portage_lines(atom_repos)
    steps = []
    for sub, lines in (("package.accept_keywords", keywords), ("package.use", use)):
        if not lines:
            continue
        d = f"{PORTAGE_DIR}/{sub}"
        body = "\\n".join(lines)
        steps.append(["sh", "-c", f"mkdir -p {d} && printf '{body}\\n' > {d}/ricelin"])
    return steps


def portage_config_files():
    """The override files this installer may have written, for uninstall."""
    return [f"{PORTAGE_DIR}/package.accept_keywords/ricelin",
            f"{PORTAGE_DIR}/package.use/ricelin"]


def ensure_aur_helper_steps():
    """
    The commands to bootstrap yay on Arch, in order, when no helper is on PATH yet;
    an empty list when one already is. yay-bin is the prebuilt package, so it skips
    the from-source compile. The pacman step carries its own sudo since it installs
    the build deps as root; the git clone and makepkg steps stay un-wrapped because
    they must run as the user (makepkg refuses to build under root).

    The build dir is a fixed path string, not a live mkdtemp, so merely composing
    the step list (a dry-run preview does exactly that) creates nothing on disk; the
    git clone is what brings the directory into being when the steps actually run.
    The clone step wipes any leftover from an earlier failed attempt first, so a
    retry never dies on "destination path already exists".
    """
    if aur_helper() is not None:
        return []
    build_dir = shlex.quote(os.path.join(tempfile.gettempdir(), "ricelin-yay-build"))
    return [
        [distro.ROOT, "pacman", "-S", "--needed", "--noconfirm", "git", "base-devel"],
        ["sh", "-c",
         f"rm -rf {build_dir} && git clone https://aur.archlinux.org/yay-bin.git {build_dir}"],
        ["sh", "-c", f"cd {build_dir} && makepkg -si --noconfirm"],
    ]


def privileged(argv, family):
    """
    Wrap a native install or repo command with sudo for the terminal path. Only
    ever call this on pacman/apt-get/dnf/zypper or repo argv. AUR-helper installs
    and cargo builds run as the user and escalate themselves, so wrapping them in
    sudo would break makepkg and poison the cargo cache; they must stay un-wrapped.
    """
    _require_family(family)
    return [distro.ROOT, *argv]


def _write_os_release(fields):
    """Write a throwaway os-release with these fields and return its path, for tests."""
    fd, path = tempfile.mkstemp(prefix="ricelin-osr-")
    with os.fdopen(fd, "w") as fh:
        for k, v in fields.items():
            fh.write(f'{k}="{v}"\n')
    return path


def _selftest():
    checks = 0

    assert install_argv(["foo"], "arch") == ["pacman", "-S", "--needed", "--noconfirm", "foo"]
    checks += 1
    assert install_argv(["foo", "bar"], "debian") == ["apt-get", "install", "-y", "foo", "bar"]
    checks += 1
    assert install_argv(["foo"], "fedora")[:3] == ["dnf", "install", "-y"]
    checks += 1
    assert install_argv(["foo"], "suse") == ["zypper", "--non-interactive", "install", "foo"]
    checks += 1

    helper = aur_helper()
    if helper:
        assert install_argv(["dotool"], "arch", aur=True) == [
            helper, "-S", "--needed", "--noconfirm", "dotool"]
        checks += 1

    copr = enable_repo_argv("copr:solopasha/hyprland", "fedora")
    assert copr == [
        ["sh", "-c",
         "dnf install -y dnf-plugins-core 2>/dev/null; "
         "dnf install -y dnf5-plugins 2>/dev/null; true"],
        ["dnf", "copr", "enable", "-y", "solopasha/hyprland"],
    ]
    checks += 1

    # Leap vs Tumbleweed build target is read off os-release, not hardcoded.
    assert _obs_build_target(_write_os_release({"ID": "opensuse-leap", "VERSION_ID": "15.6"})) \
        == "openSUSE_Leap_15.6"
    assert _obs_build_target(_write_os_release({"ID": "opensuse-tumbleweed", "VERSION_ID": "20260626"})) \
        == "openSUSE_Tumbleweed"
    checks += 2

    # ppa gates on Ubuntu-likeness: full steps there, [] on plain Debian.
    ubuntu_osr = _write_os_release({"ID": "linuxmint", "ID_LIKE": "ubuntu debian"})
    debian_osr = _write_os_release({"ID": "debian"})
    assert _ubuntu_like(ubuntu_osr) is True
    assert _ubuntu_like(debian_osr) is False
    ppa = enable_repo_argv("ppa:avengemedia/danklinux", "debian")
    if _ubuntu_like():
        assert ppa[1] == ["add-apt-repository", "-y", "ppa:avengemedia/danklinux"]
    else:
        assert ppa == []
    checks += 3

    obs = enable_repo_argv("obs:home:AvengeMedia:danklinux", "suse")
    assert obs[0] == ["zypper", "--non-interactive", "addrepo",
                      "https://download.opensuse.org/repositories/"
                      "home:/AvengeMedia:/danklinux/%s/" % _obs_build_target(),
                      "home_AvengeMedia_danklinux"]
    assert obs[1] == ["zypper", "--non-interactive", "--gpg-auto-import-keys", "refresh"]
    checks += 2

    assert refresh_argv("arch") == ["sudo", "pacman", "-Sy"]
    assert refresh_argv("debian") == ["sudo", "apt-get", "update"]
    assert refresh_argv("fedora") == ["sudo", "dnf", "makecache"]
    assert refresh_argv("suse") == ["sudo", "zypper", "--non-interactive", "refresh"]
    assert refresh_argv("gentoo") == ["sudo", "emerge", "--sync"]
    checks += 5

    assert install_argv(["gui-wm/hyprland"], "gentoo") == ["emerge", "--noreplace", "gui-wm/hyprland"]
    guru = enable_repo_argv("overlay:guru", "gentoo")
    assert guru[1] == ["sh", "-c", "portageq get_repo_path / guru >/dev/null 2>&1 || "
                                   "eselect repository enable guru"]
    assert guru[2] == ["emerge", "--sync", "guru"]
    kw, use = portage_lines({"gui-wm/hyprland": "overlay:hyproverlay",
                             "gui-apps/quickshell": "overlay:guru", "app-shells/fish": None,
                             "app-shells/zoxide": None, "media-sound/cava": None})
    assert kw == ["*/*::hyproverlay ~amd64", "dev-libs/wayland ~amd64",
                  "dev-libs/wayland-protocols ~amd64", "dev-util/wayland-scanner ~amd64",
                  "gui-apps/quickshell ~amd64", "app-shells/zoxide ~amd64"], kw
    assert use == ["gui-wm/hyprland LUA_SINGLE_TARGET: lua5-4",
                   "gui-apps/quickshell -crash-handler", "media-sound/cava pipewire"], use
    assert portage_lines({"app-misc/jq": None}) == ([], [])
    steps = portage_config_argv({"gui-wm/hyprland": "overlay:hyproverlay"})
    assert steps[0][2].startswith("mkdir -p /etc/portage/package.accept_keywords && printf")
    assert steps[0][2].endswith("> /etc/portage/package.accept_keywords/ricelin")
    assert "LUA_SINGLE_TARGET" in steps[1][2]
    assert portage_config_argv({"app-misc/jq": None}) == []
    checks += 7

    # doas swaps in for every privileged step once the wizard picks it
    distro.ROOT = "doas"
    assert privileged(["emerge", "x"], "gentoo") == ["doas", "emerge", "x"]
    assert refresh_argv("arch")[0] == "doas"
    distro.ROOT = "sudo"
    checks += 2

    assert INSTALL_ENV == {"DEBIAN_FRONTEND": "noninteractive"}
    checks += 1

    assert privileged(["pacman", "-S", "x"], "arch") == ["sudo", "pacman", "-S", "x"]
    checks += 1

    # Real read-only queries against this Arch box prove the is_installed path works.
    assert is_installed("pacman", "arch") is True
    assert is_installed("bash", "arch") is True
    assert is_installed("definitely-not-a-real-pkg-xyz", "arch") is False
    checks += 3

    print(f"pkg.py selftest: {checks} checks passed")


if __name__ == "__main__":
    _selftest()
