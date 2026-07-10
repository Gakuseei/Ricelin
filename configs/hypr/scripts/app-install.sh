#!/usr/bin/env bash
#
# Drop-installer for the pill launcher. Extends the AppImage handler to every
# file type the pill accepts as a drop: native packages, flatpakref, userland
# archives (the Depot path), fonts and wallpapers. It sources appimage-install.sh
# to reuse the registry, slug, icon and desktop-writing helpers, and answers the
# launcher on one tab-separated line prefixed with the kind so the pill can toast
# the right thing.
#
# Usage:
#   app-install.sh install <file>   -> prints "<kind>\t<name>\t<action>"  (kind = app|native|font|wallpaper)
#   app-install.sh remove  <slug>
#   app-install.sh rename  <slug> <new name>
#
set -euo pipefail

. "$(dirname "$0")/appimage-install.sh"

# The sourced cleanup ends on a failing test when no tmpdir was made, and an EXIT
# trap that fails clobbers the script's real exit code; preserve $? here so the
# font, wallpaper and native paths (which make no tmpdir) still report success.
cleanup() { local rc=$?; [ -n "${_tmpdir:-}" ] && rm -rf "$_tmpdir"; return "$rc"; }

# Locate the first executable ELF in an extracted tree, ignoring shared-lib dirs,
# preferring one under a bin/ dir and otherwise the largest. Empty when the tree
# holds no binary (source-only tarballs fail honestly on that).
find_app_binary() {
	local tree="$1" f magic sz best="" bestsz=0 binmatch=""
	while IFS= read -r f; do
		case "$f" in */lib/* | */lib64/* | */libexec/*) continue ;; esac
		magic="$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
		[ "$magic" = "7f454c46" ] || continue
		[ -n "$binmatch" ] || case "$f" in */bin/*) binmatch="$f" ;; esac
		sz="$(stat -c%s "$f" 2>/dev/null || echo 0)"
		if [ "$sz" -gt "$bestsz" ]; then bestsz="$sz"; best="$f"; fi
	done < <(find "$tree" -type f -perm -u+x 2>/dev/null)
	[ -n "$binmatch" ] && { printf '%s\n' "$binmatch"; return 0; }
	[ -n "$best" ] && printf '%s\n' "$best"
	return 0
}

# The Depot-style path: unpack an archive into a self-contained ~/Applications
# tree, resolve the app binary out of its .desktop (or by scanning for an ELF),
# and write a launcher entry pointing at that binary.
extract_install() {
	local src="$1" base stem tmp tree
	base="$(basename "$src")"

	# Strip the archive suffix before slugging, else ".tar.gz" leaks into the
	# slug as name tokens ("krita-tar-gz").
	stem="$base"
	case "$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]')" in
		*.tar.gz | *.tar.xz | *.tar.bz2 | *.tar.zst) stem="${stem%.*}"; stem="${stem%.*}" ;;
		*.tgz | *.txz | *.tbz2 | *.zip | *.deb | *.rpm) stem="${stem%.*}" ;;
	esac

	_tmpdir="$(mktemp -d)"
	tmp="$_tmpdir"

	# bsdtar reads tar, zip, rpm and the deb ar wrapper alike.
	bsdtar -xf "$src" -C "$tmp"

	tree="$tmp"
	case "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" in
		*.deb)
			# The payload of a .deb lives inside its data.tar.*; unwrap that one
			# member into its own subdir and treat it as the tree.
			local datatar sub
			datatar="$(find "$tmp" -maxdepth 1 -name 'data.tar.*' | head -1)"
			[ -n "$datatar" ] || die "no data.tar in $base"
			sub="$tmp/_data"
			mkdir -p "$sub"
			bsdtar -xf "$datatar" -C "$sub"
			tree="$sub"
			;;
	esac

	# Collapse a lone top-level wrapper dir, the usual shape of release tarballs.
	local entries
	entries="$(find "$tree" -mindepth 1 -maxdepth 1)"
	if [ "$(printf '%s\n' "$entries" | grep -c .)" = "1" ] && [ -d "$entries" ]; then
		tree="$entries"
	fi

	local df=""
	df="$(find "$tree" -path '*usr/share/applications*' -name '*.desktop' 2>/dev/null | head -1)"
	[ -n "$df" ] || df="$(find "$tree" -path '*share/applications*' -name '*.desktop' 2>/dev/null | head -1)"
	[ -n "$df" ] || df="$(find "$tree" -name '*.desktop' 2>/dev/null | head -1)"

	local dname="" iconname="" categories="" wmclass="" exec_line=""
	if [ -n "$df" ]; then
		dname="$(grep -m1 '^Name=' "$df" | cut -d= -f2- || true)"
		iconname="$(grep -m1 '^Icon=' "$df" | cut -d= -f2- || true)"
		categories="$(grep -m1 '^Categories=' "$df" | cut -d= -f2- || true)"
		wmclass="$(grep -m1 '^StartupWMClass=' "$df" | cut -d= -f2- || true)"
		exec_line="$(grep -m1 '^Exec=' "$df" | cut -d= -f2- || true)"
	fi

	local bin="" execbin execargs=""
	if [ -n "$exec_line" ]; then
		execbin="${exec_line%% *}"
		execbin="${execbin##*/}"
		execbin="${execbin%\"}"
		execbin="${execbin#\"}"
		case "$exec_line" in *" "*) execargs="${exec_line#* }" ;; esac
		# A bare name match is not enough: VS Code ships a bash-completion FILE
		# also called "code". Only an ELF (or executable script) may win, ELF first.
		local cand magic script=""
		if [ -n "$execbin" ]; then
			while IFS= read -r cand; do
				magic="$(head -c4 "$cand" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
				if [ "$magic" = "7f454c46" ]; then bin="$cand"; break; fi
				[ -n "$script" ] || { [ -x "$cand" ] && [ "$(head -c2 "$cand" 2>/dev/null)" = "#!" ] && script="$cand"; }
			done < <(find "$tree" -type f -name "$execbin" 2>/dev/null)
			[ -n "$bin" ] || bin="$script"
		fi
	fi
	[ -n "$bin" ] || bin="$(find_app_binary "$tree")"
	[ -n "$bin" ] || die "no app inside $base"

	local slug name action dest appid
	slug="$(slugify "$stem")"
	name="${dname:-$(prettify "$stem")}"
	appid="${wmclass:-${name:-$slug}}"

	# Same identity rule as install_appimage: a matching appId replaces the old
	# install, a different app that happens to slugify the same gets its own
	# numbered key instead of clobbering the stranger's entry.
	local prevPath="" prevId=""
	prevPath="$(jq -r --arg s "$slug" '.[$s].appimagePath // empty' "$registry")"
	if [ -z "$prevPath" ]; then
		action="new"
	else
		prevId="$(jq -r --arg s "$slug" '.[$s].appId // empty' "$registry")"
		if [ -z "$prevId" ] || [ "$prevId" = "$appid" ]; then
			action="updated"
			local real="" appsreal
			appsreal="$(realpath "$apps_dir" 2>/dev/null || printf '%s' "$apps_dir")"
			[ -d "$prevPath" ] && real="$(realpath "$prevPath" 2>/dev/null || true)"
			if [ -n "$real" ] && [ "$real" != "$appsreal" ]; then
				case "$real" in "$appsreal"/*) rm -rf "$prevPath" ;; esac
			else
				rm -f "$prevPath"
			fi
		else
			local n=2
			while [ -n "$(jq -r --arg s "$slug-$n" '.[$s].appimagePath // empty' "$registry")" ]; do
				n=$((n + 1))
			done
			slug="$slug-$n"
			action="new"
		fi
	fi
	dest="$apps_dir/$slug"

	rm -rf "$dest"
	mkdir -p "$dest"
	cp -a "$tree"/. "$dest"/

	local relbin binpath
	relbin="${bin#"$tree"/}"
	binpath="$dest/$relbin"
	chmod +x "$binpath"

	install_icon "$dest" "$iconname" "$slug"
	local icon_path="$icon_dir/$slug.png"
	[ -f "$icon_path" ] || { icon_path="$icon_dir/$slug.svg"; [ -f "$icon_path" ] || icon_path=""; }

	local df_out="$desktop_dir/ricelin-$slug.desktop"
	{
		echo "[Desktop Entry]"
		echo "Type=Application"
		echo "Name=$name"
		if [ -n "$execargs" ]; then
			echo "Exec=\"$binpath\" $execargs"
		else
			echo "Exec=\"$binpath\" %U"
		fi
		[ -n "$icon_path" ] && echo "Icon=$icon_path"
		[ -n "$categories" ] && echo "Categories=$categories"
		[ -n "$wmclass" ] && echo "StartupWMClass=$wmclass"
		echo "Terminal=false"
		echo "X-Ricelin-AppImage=true"
	} >"$df_out"

	reg_set "$slug" "$name" "$dest" "$icon_path" "$df_out" "$appid"
	update-desktop-database "$desktop_dir" 2>/dev/null || true

	printf 'app\t%s\t%s\n' "$name" "$action"
}

install_font() {
	local src="$1" base="$2" fonts name dest action
	fonts="$data_home/fonts"
	mkdir -p "$fonts"
	name="${base%.*}"
	dest="$fonts/$base"
	[ -f "$dest" ] && action="updated" || action="new"
	cp -f "$src" "$dest"
	fc-cache -f "$fonts" >/dev/null 2>&1 || true
	printf 'font\t%s\t%s\t%s\n' "$name" "$action" "$dest"
}

install_wallpaper() {
	local src="$1" base="$2" name wpdir dest
	name="${base%.*}"
	wpdir="$(jq -r '.wallpaperDir // ""' "${XDG_STATE_HOME:-$HOME/.local/state}/ricelin/flags.json" 2>/dev/null || echo "")"
	[ -n "$wpdir" ] || wpdir="$HOME/Ricelin/wallpapers"
	mkdir -p "$wpdir"
	case "$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')" in
		*.webp) dest="$wpdir/$name.png"; magick "$src" "$dest" ;;
		*) dest="$wpdir/$base"; cp -f "$src" "$dest" ;;
	esac
	bash "$(dirname "$0")/wallpaper.sh" set "$dest"
	printf 'wallpaper\t%s\t%s\n' "$name" "set"
}

app_install() {
	local src="$1"
	[ -n "$src" ] || die "usage: app-install.sh install <file>"
	[ -f "$src" ] || die "no such file: $src"
	local base low
	base="$(basename "$src")"
	low="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
	case "$low" in
		*.appimage)
			# Run in this shell (not $(...)): a command substitution would strand
			# install_appimage's _tmpdir in a subshell the EXIT trap never cleans.
			local out line
			out="$(mktemp)"
			install_appimage "$src" >"$out"
			line="$(cat "$out")"
			rm -f "$out"
			printf 'app\t%s\t%s\n' "$(printf '%s' "$line" | cut -f2)" "$(printf '%s' "$line" | cut -f3)"
			;;
		*.pkg.tar.zst | *.pkg.tar.xz | *.pkg.tar.gz | *.pkg.tar.bz2)
			command -v pacman >/dev/null 2>&1 || die "unsupported here"
			pkexec pacman -U --noconfirm "$src"
			printf 'native\t%s\t%s\n' "$(prettify "$base")" "new"
			;;
		*.deb)
			if command -v apt-get >/dev/null 2>&1; then
				pkexec apt-get install -y "$src"
				printf 'native\t%s\t%s\n' "$(prettify "$base")" "new"
			else
				extract_install "$src"
			fi
			;;
		*.rpm)
			if command -v dnf >/dev/null 2>&1; then
				pkexec dnf install -y "$src"
				printf 'native\t%s\t%s\n' "$(prettify "$base")" "new"
			elif command -v zypper >/dev/null 2>&1; then
				pkexec zypper --non-interactive install --allow-unsigned-rpm "$src"
				printf 'native\t%s\t%s\n' "$(prettify "$base")" "new"
			else
				extract_install "$src"
			fi
			;;
		*.flatpakref)
			command -v flatpak >/dev/null 2>&1 || die "unsupported here"
			flatpak install --user -y --noninteractive "$src"
			printf 'native\t%s\t%s\n' "$(prettify "$base")" "new"
			;;
		*.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.tbz2 | *.tar.zst | *.zip)
			extract_install "$src"
			;;
		*.ttf | *.otf)
			install_font "$src" "$base"
			;;
		*.png | *.jpg | *.jpeg | *.webp)
			install_wallpaper "$src" "$base"
			;;
		*)
			die "unsupported: $base"
			;;
	esac
}

cmd="${1:-}"
case "$cmd" in
	install) app_install "${2:-}" ;;
	remove) remove_appimage "${2:-}" ;;
	rename) rename_appimage "${2:-}" "${3:-}" ;;
	*) die "usage: app-install.sh install|remove|rename ..." ;;
esac
