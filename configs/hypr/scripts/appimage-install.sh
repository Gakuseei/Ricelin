#!/usr/bin/env bash
#
# AppImage installer for the pill launcher. Given a dropped .AppImage it copies
# the binary into ~/Applications, pulls the bundled name and icon out of the
# squashfs, writes a .desktop entry the launcher can rank, and records the paths
# in a small registry so the entry can be renamed or removed later.
#
# The metadata pass runs the dropped file with `--appimage-extract`, so an
# AppImage is trusted to the same degree as double-clicking it would be.
#
# Usage:
#   appimage-install.sh install <path-to.AppImage>   -> prints "<slug>\t<name>\t<new|updated|reinstalled>"
#   appimage-install.sh remove  <slug>
#   appimage-install.sh rename  <slug> <new name>
#
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
apps_dir="$HOME/Applications"
desktop_dir="$data_home/applications"
icon_dir="$data_home/ricelin/appimages"
registry="$data_home/ricelin/appimages.json"

mkdir -p "$apps_dir" "$desktop_dir" "$icon_dir"
[ -f "$registry" ] || echo '{}' >"$registry"

_tmpdir=""
cleanup() { [ -n "$_tmpdir" ] && rm -rf "$_tmpdir"; }
trap cleanup EXIT

die() { echo "$1" >&2; exit 1; }

# Drop architecture and pure-version tokens (1.2.3, v2) but keep name tokens that
# carry letters, so "1Password" and "v2ray" survive while "Krita-5.2.0-x86_64"
# reduces to "Krita".
strip_tokens() {
	local base="$1" out="" tok low
	base="${base%.AppImage}"
	base="${base%.appimage}"
	local IFS='._-'
	for tok in $base; do
		[ -n "$tok" ] || continue
		low="$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')"
		case "$low" in
			x86_64 | amd64 | x86 | i386 | i686 | aarch64 | arm64 | armhf | arm | linux | gnu | glibc | musl | static | portable) continue ;;
		esac
		printf '%s' "$tok" | grep -qE '^[vV]?[0-9]+([.][0-9]+)*$' && continue
		out="$out $tok"
	done
	printf '%s' "${out# }"
}

slugify() {
	local s
	s="$(strip_tokens "$1")"
	s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
	[ -n "$s" ] || s="app"
	printf '%s' "$s"
}

prettify() {
	local s
	s="$(strip_tokens "$1")"
	[ -n "$s" ] || s="${1%.[Aa]pp[Ii]mage}"
	printf '%s' "$s"
}


is_appimage() {
	local f="$1"
	[ -f "$f" ] || return 1
	case "$f" in
		*.AppImage | *.appimage) ;;
		*) return 1 ;;
	esac
	local magic
	magic="$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')"
	[ "$magic" = "7f454c46" ]
}

reg_set() {
	local slug="$1" name="$2" appimg="$3" icon="$4" desktop="$5" appid="$6" tmp
	tmp="$(mktemp)"
	jq --arg s "$slug" --arg n "$name" --arg a "$appimg" --arg i "$icon" --arg d "$desktop" --arg p "$appid" \
		'.[$s] = {name:$n, appimagePath:$a, iconPath:$i, desktopPath:$d, appId:$p}' "$registry" >"$tmp"
	mv "$tmp" "$registry"
}

install_appimage() {
	local src="$1"
	is_appimage "$src" || die "not an appimage: $src"

	local fname dest slug
	fname="$(basename "$src")"
	dest="$apps_dir/$fname"
	slug="$(slugify "$fname")"

	# Skip the copy when the drop already lives in ~/Applications, else cp aborts
	# copying a file onto itself.
	[ "$src" -ef "$dest" ] || cp -f "$src" "$dest"
	chmod +x "$dest"

	_tmpdir="$(mktemp -d)"
	local tmp="$_tmpdir"

	local name="" iconname="" categories="" wmclass="" root=""
	if (cd "$tmp" && timeout 60 "$dest" --appimage-extract >/dev/null 2>&1) && [ -d "$tmp/squashfs-root" ]; then
		root="$tmp/squashfs-root"
		local df
		df="$(find "$root" -maxdepth 2 -name '*.desktop' | head -1)"
		if [ -n "$df" ]; then
			name="$(grep -m1 '^Name=' "$df" | cut -d= -f2- || true)"
			iconname="$(grep -m1 '^Icon=' "$df" | cut -d= -f2- || true)"
			categories="$(grep -m1 '^Categories=' "$df" | cut -d= -f2- || true)"
			wmclass="$(grep -m1 '^StartupWMClass=' "$df" | cut -d= -f2- || true)"
		fi
	fi
	[ -n "$name" ] || name="$(prettify "$fname")"

	# Stable identity so a new version replaces the old, but a different app that
	# happens to slugify the same gets its own numbered key instead of clobbering.
	local appid="${wmclass:-${name:-$slug}}"
	local action prevPath prevId
	prevPath="$(jq -r --arg s "$slug" '.[$s].appimagePath // empty' "$registry")"
	if [ -z "$prevPath" ]; then
		action="new"
	elif [ "$prevPath" -ef "$dest" ] 2>/dev/null || [ "$prevPath" = "$dest" ]; then
		action="reinstalled"
	else
		prevId="$(jq -r --arg s "$slug" '.[$s].appId // empty' "$registry")"
		if [ -z "$prevId" ] || [ "$prevId" = "$appid" ]; then
			action="updated"
			rm -f "$prevPath"
		else
			local n=2
			while [ -n "$(jq -r --arg s "$slug-$n" '.[$s].appimagePath // empty' "$registry")" ]; do
				n=$((n + 1))
			done
			slug="$slug-$n"
			action="new"
		fi
	fi

	[ -n "$root" ] && install_icon "$root" "$iconname" "$slug"

	local icon_path="$icon_dir/$slug.png"
	[ -f "$icon_path" ] || { icon_path="$icon_dir/$slug.svg"; [ -f "$icon_path" ] || icon_path=""; }

	local df_out="$desktop_dir/ricelin-$slug.desktop"
	{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Name=$name"
		echo "Exec=\"$dest\" %U"
		[ -n "$icon_path" ] && echo "Icon=$icon_path"
		[ -n "$categories" ] && echo "Categories=$categories"
		[ -n "$wmclass" ] && echo "StartupWMClass=$wmclass"
		echo "Terminal=false"
		echo "X-Ricelin-AppImage=true"
	} >"$df_out"

	reg_set "$slug" "$name" "$dest" "$icon_path" "$df_out" "$appid"
	update-desktop-database "$desktop_dir" 2>/dev/null || true

	printf '%s\t%s\t%s\n' "$slug" "$name" "$action"
}

# Pick the best icon out of an extracted squashfs and copy it to the icon dir.
# Prefers a scalable svg, then the largest raster in the theme, then the bundled
# .DirIcon, then any loose image at the squashfs root.
install_icon() {
	local root="$1" iconname="$2" slug="$3" found="" sz

	# Clear any prior icon first so an update whose new bundle ships none does not
	# keep showing the stale one.
	rm -f "$icon_dir/$slug.png" "$icon_dir/$slug.svg"

	case "$iconname" in */*) iconname="${iconname##*/}" ;; esac
	case "$iconname" in *.png | *.svg | *.xpm) iconname="${iconname%.*}" ;; esac

	if [ -n "$iconname" ]; then
		found="$(find "$root" -path '*/scalable/*' -name "$iconname.svg" 2>/dev/null | head -1)"
		if [ -z "$found" ]; then
			for sz in 1024x1024 512x512 256x256 128x128 96x96 64x64 48x48; do
				found="$(find "$root" -path "*/$sz/*" -name "$iconname.png" 2>/dev/null | head -1)"
				[ -n "$found" ] && break
			done
		fi
		[ -z "$found" ] && found="$(find "$root" -name "$iconname.svg" -o -name "$iconname.png" 2>/dev/null | head -1)"
	fi

	if [ -z "$found" ] && [ -e "$root/.DirIcon" ]; then
		found="$(readlink -f "$root/.DirIcon" 2>/dev/null || true)"
		[ -n "$found" ] && [ -f "$found" ] || found="$root/.DirIcon"
	fi
	[ -z "$found" ] && found="$(find "$root" -maxdepth 1 \( -name '*.png' -o -name '*.svg' \) 2>/dev/null | head -1)"

	[ -n "$found" ] && [ -f "$found" ] || return 0
	local ext="png"
	case "$found" in *.svg) ext="svg" ;; esac
	cp -f "$found" "$icon_dir/$slug.$ext"
}

remove_appimage() {
	local slug="$1"
	[ -n "$slug" ] || die "no slug"
	local appimg icon desktop
	appimg="$(jq -r --arg s "$slug" '.[$s].appimagePath // empty' "$registry")"
	icon="$(jq -r --arg s "$slug" '.[$s].iconPath // empty' "$registry")"
	desktop="$(jq -r --arg s "$slug" '.[$s].desktopPath // empty' "$registry")"
	if [ -n "$appimg" ]; then
		# extract installs record a directory tree under $apps_dir; wipe the whole
		# tree for those, but never rm -rf a stray path outside it.
		local real="" appsreal
		[ -d "$appimg" ] && real="$(realpath "$appimg" 2>/dev/null || true)"
		appsreal="$(realpath "$apps_dir" 2>/dev/null || echo "$apps_dir")"
		case "$real" in
			"$appsreal"/*) rm -rf "$appimg" ;;
			*) rm -f "$appimg" ;;
		esac
	fi
	[ -n "$icon" ] && rm -f "$icon"
	[ -n "$desktop" ] && rm -f "$desktop"
	local tmp
	tmp="$(mktemp)"
	jq --arg s "$slug" 'del(.[$s])' "$registry" >"$tmp" && mv "$tmp" "$registry"
	update-desktop-database "$desktop_dir" 2>/dev/null || true
}

rename_appimage() {
	local slug="$1" newname="$2" desktop tmp
	[ -n "$slug" ] && [ -n "$newname" ] || die "usage: rename <slug> <name>"
	desktop="$(jq -r --arg s "$slug" '.[$s].desktopPath // empty' "$registry")"
	[ -n "$desktop" ] && [ -f "$desktop" ] || die "unknown slug: $slug"
	tmp="$(mktemp)"
	newname="$newname" awk 'BEGIN { n = ENVIRON["newname"] } !done && /^Name=/ { print "Name=" n; done = 1; next } { print }' "$desktop" >"$tmp" && mv "$tmp" "$desktop"
	tmp="$(mktemp)"
	jq --arg s "$slug" --arg n "$newname" '.[$s].name = $n' "$registry" >"$tmp" && mv "$tmp" "$registry"
	update-desktop-database "$desktop_dir" 2>/dev/null || true
}

[ "${BASH_SOURCE[0]}" = "${0}" ] || return 0

cmd="${1:-}"
case "$cmd" in
	install) install_appimage "${2:-}" ;;
	remove) remove_appimage "${2:-}" ;;
	rename) rename_appimage "${2:-}" "${3:-}" ;;
	*) die "usage: appimage-install.sh install|remove|rename ..." ;;
esac
