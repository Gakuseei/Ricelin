#!/usr/bin/env python3
"""
Update engine for the Ricelin rice. The in-app Settings updater shells out to
this and parses the single JSON object it prints on stdout.

The model: keep a dedicated pristine clone that the user never touches, so a pull
is always clean. Code files (the QML shell, helper scripts, everything that isn't
hardware or taste config) get overwritten with upstream wholesale. The handful of
protected files that hold a user's machine and preferences (monitors, binds, env
and so on) get three-way merged against the version they were last reconciled to,
so a personal edit survives an upstream change as long as the two don't touch the
same lines. An overlapping change is reported as a conflict and the live file is
left exactly as the user had it.

A manifest records the upstream sha each protected file was last reconciled to and
the upstream sha of the last successful apply, which is also the base for the next
three-way merge and the start of the changelog range.

The maintainer and anyone who installed by symlinking the config into a git
work-tree are detected as devmode and left alone, since they update with plain git.
"""
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DEFAULT_REMOTE = "https://github.com/Gakuseei/Ricelin.git"

PROTECTED = [
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
    "fish/config.fish",
]


def data_dir():
    base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(base) / "ricelin-update"


def manifest_path():
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "ricelin" / "update.json"


def git(repo, *args, check=True):
    """Run a git command inside repo and return stdout, raising on failure when check."""
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True, check=check,
    ).stdout


class CorruptManifest(Exception):
    """The manifest exists but cannot be parsed, so we must not treat it as first run."""


def load_manifest():
    """
    A missing manifest is a legit first run and returns the empty baseline. A present
    but unparseable one is corrupt and raised, never silently reset to first run,
    since that would re-baseline every protected file to HEAD and skip every change
    between the lost base and HEAD.
    """
    path = manifest_path()
    if not path.exists():
        return {"syncedSha": None, "modules": {}}
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise CorruptManifest(str(exc))


def atomic_write_bytes(path, data):
    """
    Write data to path through a temp file in the same directory, then os.replace.
    A crash mid-write leaves either the old file or the new one, never a half file.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp-", suffix=path.name)
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def save_manifest(manifest):
    atomic_write_bytes(manifest_path(), json.dumps(manifest, indent=2).encode("utf-8"))


def backup_protected(config_root):
    """
    Snapshot every live protected file into one timestamped dir under the data dir
    before an apply touches them, so a bad merge stays recoverable. Returns the
    backup dir, created lazily on first file actually copied, or None when nothing
    was live to back up.
    """
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    dest_root = data_dir().parent / "ricelin-update-backup" / stamp
    made = None
    for rel in PROTECTED:
        live = config_root / rel
        if not live.exists():
            continue
        dest = dest_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(live, dest)
        made = dest_root
    return made


def in_git_worktree(path):
    """True when path lives inside a git work-tree, used to spot devmode installs."""
    try:
        out = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "--is-inside-work-tree"],
            capture_output=True, text=True, check=False,
        ).stdout.strip()
        return out == "true"
    except OSError:
        return False


def is_devmode(config_root):
    """
    A symlinked config subtree resolving into a git work-tree updates via plain
    git, never through this engine. Either hypr or quickshell qualifying is enough,
    so a partial install that only symlinks one of them still counts. resolve()
    follows the link fully first so a relative link or one whose target nests inside
    a work-tree is caught too.
    """
    for name in ("hypr", "quickshell"):
        sub = config_root / name
        if sub.is_symlink() and in_git_worktree(sub.resolve()):
            return True
    return False


def ensure_clone(remote, do_fetch):
    """Clone the pristine mirror if missing, otherwise fetch. Returns the clone path."""
    clone = data_dir()
    if (clone / ".git").exists():
        if do_fetch:
            git(clone, "fetch", "origin", "main")
        return clone
    clone.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "clone", "--quiet", remote, str(clone)],
        capture_output=True, text=True, check=True,
    )
    return clone


def origin_head(clone):
    return git(clone, "rev-parse", "origin/main").strip()


def commit_date(clone, sha):
    return git(clone, "show", "-s", "--format=%cs", sha).strip()


def short_sha(clone, sha):
    return git(clone, "rev-parse", "--short", sha).strip()


def behind_count(clone, base, head):
    if not base:
        return 0
    try:
        out = git(clone, "rev-list", "--count", f"{base}..{head}").strip()
        return int(out)
    except (subprocess.CalledProcessError, ValueError):
        return 0


def extract_changelog(clone, base, head):
    """Pull the changelog: trailer from every commit in base..head, newest first."""
    if not base:
        return []
    body = git(clone, "log", "--format=%B%x00", f"{base}..{head}")
    lines = []
    for commit in body.split("\0"):
        for line in commit.splitlines():
            stripped = line.strip()
            if stripped.lower().startswith("changelog:"):
                text = stripped.split(":", 1)[1].strip()
                if text:
                    lines.append(text)
    return lines


def tracked_config_files(clone, ref):
    """
    Every file under configs/ at ref, relative to configs/. Listed from the commit
    tree, not the clone's checked-out index, so files a newer upstream added (a new
    QML surface, say) are deployed too; ls-files would only ever see the stale
    working tree and silently skip them, leaving the live config referencing a type
    whose file never landed.
    """
    out = git(clone, "ls-tree", "-r", "--name-only", ref, "configs/")
    rels = []
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("configs/"):
            rels.append(line[len("configs/"):])
    return rels


def show_at(clone, sha, rel):
    """File content at a sha, or None when the path didn't exist there."""
    result = subprocess.run(
        ["git", "-C", str(clone), "show", f"{sha}:configs/{rel}"],
        capture_output=True, check=False,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def merge_file(theirs, base, new):
    """git merge-file semantics. Returns (merged_bytes, clean) where clean is exit 0."""
    with tempfile.TemporaryDirectory() as tmp:
        tp = Path(tmp) / "theirs"
        bp = Path(tmp) / "base"
        np = Path(tmp) / "new"
        tp.write_bytes(theirs)
        bp.write_bytes(base)
        np.write_bytes(new)
        result = subprocess.run(
            ["git", "merge-file", "-p", str(tp), str(bp), str(np)],
            capture_output=True, check=False,
        )
        return result.stdout, result.returncode == 0


def module_name(rel):
    return Path(rel).stem


def reconcile_protected(clone, config_root, manifest, head, apply, take):
    """
    Three-way merge each protected file against its recorded base sha. Returns the
    module report rows, the conflict list, and the manifest sha updates to commit on
    apply. A file with no recorded base is skipped here and baselined by the caller.
    """
    rows = []
    conflicts = []
    sha_updates = {}
    for rel in PROTECTED:
        base_sha = manifest.get("modules", {}).get(rel)
        if not base_sha:
            continue
        new = show_at(clone, head, rel)
        base = show_at(clone, base_sha, rel)
        if new is None or base is None:
            continue
        if new == base:
            rows.append({"name": module_name(rel), "path": rel, "state": "clean"})
            continue
        live_path = config_root / rel
        theirs = live_path.read_bytes() if live_path.exists() else base
        if theirs == base:
            if apply:
                atomic_write_bytes(live_path, new)
                sha_updates[rel] = head
            rows.append({"name": module_name(rel), "path": rel, "state": "update"})
            continue
        merged, clean = merge_file(theirs, base, new)
        if clean:
            if apply:
                atomic_write_bytes(live_path, merged)
                sha_updates[rel] = head
            rows.append({"name": module_name(rel), "path": rel, "state": "merged"})
        elif rel in take:
            if apply:
                atomic_write_bytes(live_path, new)
                sha_updates[rel] = head
            rows.append({"name": module_name(rel), "path": rel, "state": "update"})
        else:
            rows.append({"name": module_name(rel), "path": rel, "state": "conflict"})
            conflicts.append(rel)
    return rows, conflicts, sha_updates


def sync_code(clone, config_root, head, apply):
    """
    Overwrite every tracked config file that isn't protected with the upstream
    version. Returns True when at least one live file differed from upstream.

    ponytail: L1 known ceiling. A file deleted upstream is never removed from the
    live config, so renamed or dropped code files linger as orphans. Left as is on
    purpose, since it only ever leaves stale files and never deletes a user's data.
    """
    protected = set(PROTECTED)
    changed = False
    for rel in tracked_config_files(clone, head):
        if rel in protected:
            continue
        new = show_at(clone, head, rel)
        if new is None:
            continue
        live_path = config_root / rel
        current = live_path.read_bytes() if live_path.exists() else None
        if current == new:
            continue
        changed = True
        if apply:
            atomic_write_bytes(live_path, new)
    return changed


def baseline_modules(manifest, head):
    """First run: record head as the base for every protected file without merging."""
    mods = manifest.setdefault("modules", {})
    for rel in PROTECTED:
        mods[rel] = head


def baseline(config_root, sha):
    """
    Record the freshly installed commit as the update baseline. Without this the
    very first check has no synced sha to count from, so behind_count returns zero
    and a box that is really several commits back reports itself up to date, with no
    way to ever reach an apply that would set the baseline. The installer calls this
    right after it deploys, handing over the commit it just installed.

    No clone and no network: a baseline is only the synced sha plus the same sha as
    the merge base for every protected file. Skipped when a manifest already exists,
    so a re-run never resets a tracked baseline, and in devmode, since that path
    updates through plain git and never wants a manifest at all.
    """
    if not sha:
        return error_result("error", "baseline needs --sha")
    if is_devmode(config_root):
        return {"status": "devmode", "syncedSha": ""}
    if manifest_path().exists():
        return {"status": "kept", "syncedSha": ""}
    manifest = {"syncedSha": sha, "modules": {rel: sha for rel in PROTECTED}}
    save_manifest(manifest)
    return {"status": "baselined", "syncedSha": sha}


# ── Missing dependencies ──────────────────────────────────────────────────────
#
# A Ricelin update can introduce a new package the rice now needs (cava did once).
# The engine reads the upstream package manifest from the clone, works out which
# core packages are not installed on this machine, and offers to install the chosen
# ones on apply.
#
# The family detection and name resolution below are a deliberately inlined copy of
# installer/distro.py. The engine ships to user machines on its own and must never
# import the installer package, so the two are kept in sync by hand rather than
# shared. Only the slice this feature needs is copied.

FAMILY_TOKENS = {
    "arch": ("arch", "cachyos", "endeavouros", "manjaro", "garuda", "artix",
             "arcolinux", "archcraft", "rebornos", "athena", "blackarch", "archbang",
             "crystal", "snigdha", "parabola", "obarun", "arch32", "hyperbola", "steamos",
             "omarchy", "xerolinux", "archman", "biglinux", "ctlos", "tromjaro",
             "bluestar", "arkane", "blendos", "acreetionos", "mabox"),
    "debian": ("debian", "ubuntu", "linuxmint", "pop", "elementary", "zorin", "raspbian"),
    "fedora": ("fedora", "nobara", "rhel", "centos", "rocky", "almalinux"),
    "suse": ("suse", "opensuse", "sles", "sled", "tumbleweed", "leap"),
}


def os_release(path="/etc/os-release"):
    data = {}
    try:
        with open(path) as fh:
            for line in fh:
                if "=" in line and not line.startswith("#"):
                    k, v = line.rstrip().split("=", 1)
                    data[k] = v.strip().strip('"')
    except OSError:
        pass
    return data


def detect_family(path="/etc/os-release"):
    """Map os-release ID then ID_LIKE onto a package family, or "unknown"."""
    data = os_release(path)
    ids = [data.get("ID", "").lower()]
    ids += data.get("ID_LIKE", "").lower().split()
    for token in ids:
        for fam, names in FAMILY_TOKENS.items():
            if token in names:
                return fam
    return "unknown"


def native_name(pkg, family):
    """The native package name for this family, or None when there is none."""
    return (pkg.get("names") or {}).get(family)


def manifest_at(clone, sha):
    """
    The installer package manifest as parsed JSON at sha, read from the clone via
    git so it reflects the upstream version being applied, never the live tree. None
    when the file is absent or unparseable, so an older upstream that predates the
    manifest simply yields no dependency step.
    """
    result = subprocess.run(
        ["git", "-C", str(clone), "show", f"{sha}:installer/packages.json"],
        capture_output=True, check=False,
    )
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except ValueError:
        return None


def pkg_installed(name, family):
    """
    Whether the native package is installed, read-only and quiet. A failed query
    (wrong tool, no db) counts as not installed rather than raising, mirroring the
    installer's own is_installed.
    """
    try:
        if family == "arch":
            r = subprocess.run(["pacman", "-Qq", name], capture_output=True, text=True)
            return r.returncode == 0
        if family == "debian":
            r = subprocess.run(["dpkg-query", "-W", "-f=${Status}", name],
                               capture_output=True, text=True)
            return "install ok installed" in r.stdout
        r = subprocess.run(["rpm", "-q", name], capture_output=True, text=True)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def detect_missing_deps(clone, head):
    """
    Core packages from the upstream manifest that have a native name on this family
    and are not installed. Packages with no native name here (fallback-only ones the
    package db can't speak for) are skipped, since there is nothing to query or to
    pkexec-install. Returns rows of {id, name, desc, group}.
    """
    family = detect_family()
    manifest = manifest_at(clone, head)
    if family == "unknown" or not manifest:
        return []
    rows = []
    for pkg in manifest.get("packages", []):
        if pkg.get("group") != "core":
            continue
        name = native_name(pkg, family)
        if not name or pkg_installed(name, family):
            continue
        rows.append({"id": pkg["id"], "name": name,
                     "desc": pkg.get("desc", ""), "group": pkg.get("group")})
    return rows


def native_install_argv(family, names):
    """The bare repo-install argv (no privilege wrapper) for one or more native packages."""
    if family == "arch":
        return ["pacman", "-S", "--needed", "--noconfirm", *names]
    if family == "debian":
        return ["env", "DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y", *names]
    if family == "fedora":
        return ["dnf", "install", "-y", *names]
    return ["zypper", "--non-interactive", "install", *names]


def manual_hint(pkg, family, fallbacks):
    """
    The instruction for a dependency this engine can't install headless, returned as
    its failure reason so the user is told what to run rather than left with a silent
    no-op. An Arch AUR package needs a helper that runs makepkg as the user (it
    refuses root, and the helper's own sudo has no askpass in a pill-spawned process),
    so the engine never tries it from here and hands over the exact command. A
    fallback-only package has no native package and points at its fallback method.
    """
    name = native_name(pkg, family)
    if family == "arch" and name and pkg.get("aur"):
        helper = shutil.which("yay") or shutil.which("paru") or "yay"
        return f"AUR package, install it yourself: {helper} -S {name}"
    hint = fallbacks.get(pkg.get("fallback")) or "install it manually"
    return f"no native package on this system, {hint}"


def native_install_reason(result, os_error):
    """Why a batched repo install didn't land, kept short for the surface."""
    if os_error:
        return os_error
    # pkexec exits 126 when the prompt is dismissed and 127 when authorisation is
    # denied, the two cases that otherwise read as a silent success.
    if result.returncode in (126, 127):
        return "the password prompt was cancelled"
    tail = (result.stderr or "").strip().splitlines()
    return tail[-1] if tail else "install failed"


def install_missing_deps(clone, head, ids):
    """
    Install the chosen dependencies and return the failures as rows of {id, error};
    an empty list means everything chosen installed. Every repo (native, non-AUR)
    package goes through ONE pkexec call per family, so the user answers a single
    password prompt instead of one per package. AUR and fallback-only packages can't
    be driven headless from a GUI-spawned process, so they are reported with a manual
    hint instead of attempted and failed silently. Unknown ids and a missing manifest
    are reported as failures too, never dropped.
    """
    family = detect_family()
    manifest = manifest_at(clone, head)
    if family == "unknown" or not manifest:
        return [{"id": pid, "error": "couldn't read the package manifest"} for pid in ids]
    by_id = {p["id"]: p for p in manifest.get("packages", [])}
    fallbacks = manifest.get("fallbacks", {})

    failures = []
    repo = []  # (id, native_name) pairs to batch into one privileged install
    for pid in ids:
        pkg = by_id.get(pid)
        if pkg is None:
            failures.append({"id": pid, "error": "unknown package"})
            continue
        name = native_name(pkg, family)
        if not name or (family == "arch" and pkg.get("aur")):
            failures.append({"id": pid, "error": manual_hint(pkg, family, fallbacks)})
            continue
        repo.append((pid, name))

    if repo:
        cmd = ["pkexec", *native_install_argv(family, [n for _, n in repo])]
        result, os_error = None, ""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        except OSError as exc:
            os_error = str(exc)
        # Verify per package so a partial transaction reports only what's still missing.
        for pid, name in repo:
            if not pkg_installed(name, family):
                failures.append({"id": pid, "error": native_install_reason(result, os_error)})
    return failures


def run(mode, remote, config_root, take, install_ids):
    if is_devmode(config_root):
        return {"status": "devmode", "behind": 0, "fromDate": "", "toDate": "",
                "version": "", "changelog": [], "codeChanged": False, "modules": [],
                "conflicts": [], "missingDeps": [], "depFailures": [],
                "applied": False, "restartNeeded": False, "error": None}

    apply = mode == "apply"
    try:
        clone = ensure_clone(remote, do_fetch=True)
    except subprocess.CalledProcessError as exc:
        err = (exc.stderr or "").strip()
        return error_result(classify_git_failure(err), err or "git failed")

    manifest = load_manifest()
    head = origin_head(clone)
    base = manifest.get("syncedSha")
    first_run = base is None

    changelog = extract_changelog(clone, base, head)
    behind = behind_count(clone, base, head)
    from_date = commit_date(clone, base) if base else commit_date(clone, head)
    to_date = commit_date(clone, head)
    version = f"{short_sha(clone, head)} {to_date}"

    # Install the chosen new packages first so the post-install scan reflects them,
    # then report whatever is still missing. Detection runs in both modes.
    dep_failures = install_missing_deps(clone, head, install_ids) if (apply and install_ids) else []
    missing = detect_missing_deps(clone, head)

    if first_run:
        code_changed = sync_code(clone, config_root, head, apply)
        rows = [{"name": module_name(rel), "path": rel, "state": "clean"}
                for rel in PROTECTED]
        if apply:
            baseline_modules(manifest, head)
            manifest["syncedSha"] = head
            save_manifest(manifest)
        return {
            "status": "ok", "behind": behind, "fromDate": from_date, "toDate": to_date,
            "version": version, "changelog": changelog, "codeChanged": code_changed,
            "modules": rows, "conflicts": [], "missingDeps": missing,
            "depFailures": dep_failures, "applied": apply,
            "restartNeeded": code_changed, "error": None,
        }

    if apply:
        backup_protected(config_root)
    rows, conflicts, sha_updates = reconcile_protected(
        clone, config_root, manifest, head, apply, take)
    code_changed = sync_code(clone, config_root, head, apply)

    if apply:
        manifest.setdefault("modules", {}).update(sha_updates)
        manifest["syncedSha"] = head
        save_manifest(manifest)

    protected_changed = any(r["state"] in ("update", "merged") for r in rows)
    return {
        "status": "ok", "behind": behind, "fromDate": from_date, "toDate": to_date,
        "version": version, "changelog": changelog, "codeChanged": code_changed,
        "modules": rows, "conflicts": conflicts, "missingDeps": missing,
        "depFailures": dep_failures, "applied": apply,
        "restartNeeded": code_changed or protected_changed, "error": None,
    }


def error_result(status, message):
    return {"status": status, "behind": 0, "fromDate": "", "toDate": "", "version": "",
            "changelog": [], "codeChanged": False, "modules": [], "conflicts": [],
            "missingDeps": [], "depFailures": [], "applied": False,
            "restartNeeded": False, "error": message}


def classify_git_failure(stderr):
    """
    Map a git failure message to a status. A transient network drop is offline, a
    first clone that never landed is noclone, everything else is a real error. Used
    both for the initial clone and any later git call so a network drop after fetch
    or a missing default branch does not surface as an opaque error.
    """
    offline = any(s in stderr.lower() for s in
                  ("could not resolve", "couldn't resolve", "network", "timed out",
                   "connection", "unable to access", "failed to connect"))
    if offline:
        return "offline"
    if not (data_dir() / ".git").exists():
        return "noclone"
    return "error"


class BadArgs(Exception):
    """A flag was given without its value, surfaced as a normal error JSON."""


def take_value(argv, i, flag):
    if i >= len(argv):
        raise BadArgs(f"{flag} expects a value")
    return argv[i]


def parse_args(argv):
    mode = "check"
    remote = DEFAULT_REMOTE
    config_root = Path.home() / ".config"
    take = set()
    install_ids = set()
    sha = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("check", "apply", "baseline"):
            mode = arg
        elif arg == "--sha":
            i += 1
            sha = take_value(argv, i, "--sha")
        elif arg == "--remote":
            i += 1
            remote = take_value(argv, i, "--remote")
        elif arg == "--config-root":
            i += 1
            config_root = Path(take_value(argv, i, "--config-root")).expanduser()
        elif arg == "--take":
            i += 1
            value = take_value(argv, i, "--take")
            take = {p.strip() for p in value.split(",") if p.strip()}
        elif arg == "--install-deps":
            i += 1
            value = take_value(argv, i, "--install-deps")
            install_ids = {p.strip() for p in value.split(",") if p.strip()}
        i += 1
    return mode, remote, config_root, take, install_ids, sha


def main(argv):
    """
    Always print exactly one JSON object and exit 0 on a handled error so the in-app
    parser never sees a bare traceback. parse_args runs inside the guard too, so a
    trailing flag with no value becomes an error JSON rather than an IndexError.
    """
    try:
        mode, remote, config_root, take, install_ids, sha = parse_args(argv)
        if mode == "baseline":
            result = baseline(config_root, sha)
        else:
            result = run(mode, remote, config_root, take, install_ids)
    except BadArgs as exc:
        print(json.dumps(error_result("error", str(exc))))
        return 0
    except CorruptManifest as exc:
        print(json.dumps(error_result(
            "error", f"update manifest is corrupt and was left untouched: {exc}")))
        return 0
    except subprocess.CalledProcessError as exc:
        err = (exc.stderr or "").strip()
        print(json.dumps(error_result(classify_git_failure(err), err or "git failed")))
        return 0
    except Exception as exc:
        print(json.dumps(error_result("error", str(exc))))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
