#!/bin/sh
set -eu

REPO_URL="https://github.com/Gakuseei/Ricelin.git"
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/ricelin"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
RISHOT_INSTALL_URL="https://raw.githubusercontent.com/Gakuseei/rishot/main/install.sh"

WANT_FULL=0
WANT_SDDM=0
WANT_SERVICES=1
WANT_UNINSTALL=0
SKIP_DEPS=0
NO_PROMPT=0
SELECTION_GIVEN=0

say() { printf '%s\n' "$*"; }
step() { printf '\n:: %s\n' "$*"; }
warn() { printf 'ricelin: %s\n' "$*" >&2; }
die() { printf 'ricelin: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

CORE_PKGS="hyprland-git quickshell ghostty fish \
matugen awww cliphist wl-clipboard imagemagick jq \
brightnessctl playerctl hyprpicker hyprpolkitagent hypridle dotool \
networkmanager bluez bluez-utils pipewire wireplumber pamixer cava \
kde-cli-tools kdialog fastfetch \
ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-cjk noto-fonts-emoji \
papirus-icon-theme bibata-cursor-theme-bin"

FULL_PKGS="dolphin keepassxc zathura zathura-pdf-mupdf imv rnote"

usage() {
	cat <<EOF
Ricelin installer

  sh install.sh [options]

Run it with no options for the guided installer. Flags skip the menu:
  --full        also install the daily apps (dolphin, keepassxc, zathura, imv, rnote)
  --sddm        also install the torii SDDM login theme (system change, sudo)
  --quickstart  core defaults, no questions asked
  --no-prompt   never ask, take defaults (for headless or CI)
  --no-deps     skip the package step, only deploy the configs
  --uninstall   remove the Ricelin configs and restore the newest backup
  -h, --help    show this
EOF
}

parse_args() {
	for a in "$@"; do
		case "$a" in
		--full)
			WANT_FULL=1
			SELECTION_GIVEN=1
			;;
		--sddm)
			WANT_SDDM=1
			SELECTION_GIVEN=1
			;;
		--quickstart) SELECTION_GIVEN=1 ;;
		--no-prompt)
			NO_PROMPT=1
			SELECTION_GIVEN=1
			;;
		--no-deps) SKIP_DEPS=1 ;;
		--uninstall) WANT_UNINSTALL=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown option: $a (try --help)" ;;
		esac
	done
}

tty_dev() {
	if { true </dev/tty; } 2>/dev/null && { true >/dev/tty; } 2>/dev/null; then
		echo /dev/tty
	elif [ -t 0 ]; then
		echo /dev/stdin
	else
		echo ""
	fi
}

ESC=$(printf '\033')
CR=$(printf '\r')
NL=$(printf '\n')

if [ -z "${NO_COLOR:-}" ]; then
	C_ACCENT=$(printf '\033[38;5;209m')
	C_BOLD=$(printf '\033[1m')
	C_DIM=$(printf '\033[2m')
	C_RST=$(printf '\033[0m')
else
	C_ACCENT=''
	C_BOLD=''
	C_DIM=''
	C_RST=''
fi

MENU_TTY=''
MENU_STTY=''

restore_tty() {
	[ -n "$MENU_TTY" ] && [ -n "$MENU_STTY" ] && stty "$MENU_STTY" <"$MENU_TTY" 2>/dev/null
	MENU_STTY=''
}

toggle_current() {
	case "$MENU_CUR" in
	0) WANT_FULL=$((1 - WANT_FULL)) ;;
	1) WANT_SDDM=$((1 - WANT_SDDM)) ;;
	2) WANT_SERVICES=$((1 - WANT_SERVICES)) ;;
	esac
}

draw_rows() {
	_t="$1"
	_i=0
	for _row in \
		"full|daily apps (dolphin, keepassxc, zathura, imv)" \
		"sddm|torii SDDM login theme" \
		"services|enable NetworkManager + bluetooth"; do
		case "$_i" in
		0) _on=$WANT_FULL ;;
		1) _on=$WANT_SDDM ;;
		2) _on=$WANT_SERVICES ;;
		esac
		if [ "$_on" -eq 1 ]; then _mark="${C_ACCENT}[x]${C_RST}"; else _mark='[ ]'; fi
		if [ "$_i" -eq "$MENU_CUR" ]; then
			printf '\033[2K  %s>%s %s %s%-9s%s %s%s%s\n' \
				"$C_ACCENT" "$C_RST" "$_mark" "$C_BOLD" "${_row%%|*}" "$C_RST" \
				"$C_DIM" "${_row#*|}" "$C_RST" >"$_t"
		else
			printf '\033[2K    %s %-9s %s%s%s\n' \
				"$_mark" "${_row%%|*}" "$C_DIM" "${_row#*|}" "$C_RST" >"$_t"
		fi
		_i=$((_i + 1))
	done
}

read_key() {
	_k=$(dd bs=1 count=1 2>/dev/null <"$1"; printf x)
	printf '%s' "${_k%x}"
}

number_menu() {
	t="$1"
	while :; do
		printf '\n  Ricelin extras  (type a number to toggle, Enter to continue, q to cancel):\n' >"$t"
		printf '    %s 1) full      daily apps (dolphin, keepassxc, zathura, imv)\n' "$([ "$WANT_FULL" -eq 1 ] && echo '[x]' || echo '[ ]')" >"$t"
		printf '    %s 2) sddm      torii SDDM login theme\n' "$([ "$WANT_SDDM" -eq 1 ] && echo '[x]' || echo '[ ]')" >"$t"
		printf '    %s 3) services  enable NetworkManager + bluetooth\n' "$([ "$WANT_SERVICES" -eq 1 ] && echo '[x]' || echo '[ ]')" >"$t"
		printf '  > ' >"$t"
		read -r _ans <"$t" || _ans=""
		case "$_ans" in
		1) WANT_FULL=$((1 - WANT_FULL)) ;;
		2) WANT_SDDM=$((1 - WANT_SDDM)) ;;
		3) WANT_SERVICES=$((1 - WANT_SERVICES)) ;;
		[qQ]*)
			say "Cancelled."
			exit 0
			;;
		"") break ;;
		*) ;;
		esac
	done
}

choose_extras() {
	t="$1"
	_old=$(stty -g <"$t" 2>/dev/null) || {
		number_menu "$t"
		return 0
	}
	MENU_CUR=0
	printf '\n  %s%sRicelin%s  Hyprland shell installer\n' "$C_BOLD" "$C_ACCENT" "$C_RST" >"$t"
	printf '  %sup/down move   space tick   enter continue   q cancel%s\n\n' "$C_DIM" "$C_RST" >"$t"
	draw_rows "$t"
	MENU_TTY="$t"
	MENU_STTY="$_old"
	stty -echo -icanon min 1 time 0 <"$t" 2>/dev/null
	while :; do
		_key=$(read_key "$t")
		if [ "$_key" = "$ESC" ]; then
			_k2=$(read_key "$t")
			_k3=$(read_key "$t")
			case "$_k2$_k3" in
			'[A') MENU_CUR=$(((MENU_CUR + 2) % 3)) ;;
			'[B') MENU_CUR=$(((MENU_CUR + 1) % 3)) ;;
			esac
		else
			case "$_key" in
			' ') toggle_current ;;
			1) WANT_FULL=$((1 - WANT_FULL)) ;;
			2) WANT_SDDM=$((1 - WANT_SDDM)) ;;
			3) WANT_SERVICES=$((1 - WANT_SERVICES)) ;;
			"$CR" | "$NL") break ;;
			q | Q)
				restore_tty
				printf '\n' >"$t"
				say "Cancelled."
				exit 0
				;;
			esac
		fi
		printf '\033[3A' >"$t"
		draw_rows "$t"
	done
	restore_tty
	printf '\n' >"$t"
}

interactive_select() {
	[ "$SELECTION_GIVEN" -eq 1 ] && return 0
	[ "$NO_PROMPT" -eq 1 ] && return 0
	t="$(tty_dev)"
	[ -n "$t" ] || {
		say "No terminal for prompts, taking QuickStart defaults"
		return 0
	}
	choose_extras "$t"
}

confirm_install() {
	[ "$SELECTION_GIVEN" -eq 1 ] && return 0
	[ "$NO_PROMPT" -eq 1 ] && return 0
	t="$(tty_dev)"
	[ -n "$t" ] || return 0
	printf '\n  %sReady to install%s\n' "$C_BOLD" "$C_RST" >"$t"
	printf '    %s+%s core      Hyprland shell, deps, rishot\n' "$C_ACCENT" "$C_RST" >"$t"
	[ "$WANT_FULL" -eq 1 ] && printf '    %s+%s full      daily apps (dolphin, keepassxc, zathura, imv)\n' "$C_ACCENT" "$C_RST" >"$t"
	[ "$WANT_SDDM" -eq 1 ] && printf '    %s+%s sddm      torii SDDM login theme\n' "$C_ACCENT" "$C_RST" >"$t"
	[ "$WANT_SERVICES" -eq 1 ] && printf '    %s+%s services  NetworkManager + bluetooth\n' "$C_ACCENT" "$C_RST" >"$t"
	printf '\n  %sEnter%s to install   %sq%s to cancel\n  > ' "$C_BOLD" "$C_RST" "$C_BOLD" "$C_RST" >"$t"
	read -r _a <"$t" || _a=""
	case "$_a" in
	[qQnN]*)
		say "Cancelled."
		exit 0
		;;
	esac
}

detect_pm() {
	if have yay; then echo yay
	elif have paru; then echo paru
	elif have pacman; then echo pacman
	else echo unknown
	fi
}

bootstrap_aur_helper() {
	have yay && return 0
	have paru && return 0
	step "No AUR helper found, bootstrapping yay-bin from the AUR"
	if [ "$(id -u)" -eq 0 ]; then
		warn "run the installer as a normal user (not root); makepkg cannot build as root"
		return 1
	fi
	sudo pacman -Syu --needed --noconfirm git base-devel || {
		warn "could not install git and base-devel"
		return 1
	}
	tmp="$(mktemp -d)"
	if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
		(cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
		rm -rf "$tmp"
		have yay && {
			say "  yay installed"
			return 0
		}
	fi
	rm -rf "$tmp"
	warn "could not bootstrap an AUR helper; install yay or paru yourself, then re-run"
	return 1
}

install_deps() {
	pm="$1"
	pkgs="$CORE_PKGS"
	[ "$WANT_FULL" -eq 1 ] && pkgs="$pkgs $FULL_PKGS"

	if have Hyprland; then
		pkgs=$(printf '%s' "$pkgs" | sed 's/hyprland-git//')
		say "  Hyprland already installed, keeping it (the lua config needs a recent Hyprland)"
	fi

	case "$pm" in
	yay | paru)
		step "Syncing and installing deps via $pm"
		case "$pm" in
		paru) review="--skipreview" ;;
		*) review="--answerdiff None --answeredit None --answerclean None" ;;
		esac
		# shellcheck disable=SC2086
		"$pm" -Syu --needed --noconfirm $review $pkgs || warn "some packages failed; check the log above"
		;;
	pacman)
		step "Syncing and installing deps via pacman"
		warn "hyprland-git, rishot-git and bibata-cursor-theme-bin live in the AUR;"
		warn "pacman cannot build them. Install an AUR helper (yay or paru) for the full rice."
		# shellcheck disable=SC2086
		sudo pacman -Syu --needed --noconfirm $pkgs || warn "some packages failed (AUR ones expected to)"
		;;
	*)
		warn "no supported package manager found"
		say "Install these yourself, then re-run with --no-deps:"
		say "  $CORE_PKGS"
		return 1
		;;
	esac
}

install_rishot() {
	pm="$1"
	if have rishot; then
		say "rishot already present, skipping"
		return 0
	fi
	step "Installing rishot"
	case "$pm" in
	paru)
		"$pm" -S --needed --noconfirm --skipreview rishot-git && return 0
		warn "AUR rishot-git failed, trying the upstream installer"
		;;
	yay)
		"$pm" -S --needed --noconfirm --answerdiff None --answeredit None --answerclean None rishot-git && return 0
		warn "AUR rishot-git failed, trying the upstream installer"
		;;
	esac
	if have curl; then
		curl -fsSL "$RISHOT_INSTALL_URL" | sh || warn "rishot install failed; install it yourself for the Print key"
	else
		warn "no curl; install rishot yourself (https://github.com/Gakuseei/rishot)"
	fi
}

MARKER=".ricelin-managed"

# Path of the ownership marker for a dest. A directory carries the marker inside
# it; a file dest cannot, so it gets a sibling marker named after it. The marker
# means "Ricelin deployed this, replacing it without a backup is safe."
marker_for() {
	if [ -d "$1" ] && [ ! -L "$1" ]; then
		echo "$1/$MARKER"
	else
		echo "$(dirname "$1")/$(basename "$1")$MARKER"
	fi
}

# True when dest is one of our own deployed copies, spotted by the marker file.
is_managed() {
	[ -f "$(marker_for "$1")" ]
}

backup_path() {
	target="$1"
	[ -e "$target" ] || [ -L "$target" ] || return 0
	# Our own just-deployed copy carries the marker; skip backing that up so a
	# re-run does not pile up a fresh timestamped copy each time. A real
	# pre-existing user config has no marker and is moved aside.
	is_managed "$target" && return 0
	# An old symlink-era install left the live config as a symlink into PREFIX
	# (the clone). That is not user data, so drop it without a backup; backing it
	# up would let --uninstall restore it and re-point the live config into the
	# git worktree, which the in-app updater then refuses as devmode. A symlink
	# the user made themselves points elsewhere and is preserved like any config.
	if [ -L "$target" ]; then
		link_dest="$(readlink "$target")"
		case "$link_dest" in
		"$PREFIX"/*)
			rm -f "$target"
			return 0
			;;
		esac
	fi
	backup="${target}.bak-ricelin-$(date +%Y%m%d-%H%M%S)"
	mv "$target" "$backup"
	say "  backed up $(basename "$target") -> $(basename "$backup")"
}

copy_into_config() {
	src="$1"
	dest="$2"
	[ -e "$src" ] || {
		warn "missing in clone: $src"
		return 0
	}
	mkdir -p "$(dirname "$dest")"
	# A previous copy of ours is removed (not backed up) so the fresh copy
	# replaces it cleanly instead of nesting inside it. A real user config with
	# no marker is moved aside by backup_path first.
	if is_managed "$dest"; then
		rm -f "$(marker_for "$dest")"
		rm -rf "$dest"
	else
		backup_path "$dest"
		rm -rf "$dest"
	fi
	cp -a "$src" "$dest"
	touch "$(marker_for "$dest")"
	say "  copied $(basename "$dest")"
}

neutralize_clone() {
	mon="$PREFIX/configs/hypr/modules/monitors.lua"
	env="$PREFIX/configs/hypr/modules/env.lua"
	ghc="$PREFIX/configs/ghostty/config"

	if [ -f "$mon" ]; then
		[ -f "$mon.example" ] || cp "$mon" "$mon.example"
		cat >"$mon" <<'EOF'
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
EOF
		say "  monitors.lua set to auto-detect (your-layout template: monitors.lua.example)"
	fi

	if [ -f "$env" ]; then
		cat >"$env" <<'EOF'
hl.env("XCURSOR_THEME",   "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("QT_QPA_PLATFORMTHEME", "kde")
EOF
		if lspci 2>/dev/null | grep -qi 'nvidia'; then
			cat >>"$env" <<'EOF'

hl.env("LIBVA_DRIVER_NAME",         "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("__GL_GSYNC_ALLOWED",        "0")
hl.env("__GL_VRR_ALLOWED",          "0")
EOF
			say "  env.lua: nvidia GPU detected, kept the nvidia variables"
		else
			say "  env.lua: no nvidia GPU, dropped the nvidia variables"
		fi
	fi

	if [ -f "$ghc" ]; then
		sed -i "s#/home/erik#$HOME#g" "$ghc"
	fi
}

deploy() {
	step "Fetching Ricelin into $PREFIX"
	if [ -d "$PREFIX/.git" ]; then
		say "  updating existing clone"
		git -C "$PREFIX" checkout -- \
			configs/hypr/modules/monitors.lua \
			configs/hypr/modules/env.lua \
			configs/ghostty/config 2>/dev/null || true
		git -C "$PREFIX" pull --ff-only || warn "could not fast-forward; using the current checkout"
	else
		have git || die "git is required to fetch Ricelin"
		rm -rf "${PREFIX:?}"
		git clone --depth 1 "$REPO_URL" "$PREFIX"
	fi

	[ -f "$PREFIX/configs/quickshell/pill/shell.qml" ] || die "clone looks wrong: pill/shell.qml missing"

	neutralize_clone

	step "Copying configs into $CFG"
	copy_into_config "$PREFIX/configs/hypr" "$CFG/hypr"
	copy_into_config "$PREFIX/configs/quickshell" "$CFG/quickshell"
	copy_into_config "$PREFIX/configs/ghostty" "$CFG/ghostty"
	copy_into_config "$PREFIX/configs/kde/kdeglobals" "$CFG/kdeglobals"
	copy_into_config "$PREFIX/configs/systemd/user/hyprland-session.target" \
		"$CFG/systemd/user/hyprland-session.target"

	mkdir -p "$HOME/.cache/ricelin"
}

enable_services() {
	step "Enabling services"
	if systemctl is-active --quiet systemd-networkd 2>/dev/null || systemctl is-active --quiet iwd 2>/dev/null; then
		warn "another network manager is active; leaving NetworkManager alone"
		warn "the Link surface needs NetworkManager, switch over yourself if you want it"
	else
		sudo systemctl enable --now NetworkManager.service || warn "could not enable NetworkManager"
	fi
	sudo systemctl enable --now bluetooth.service || warn "could not enable bluetooth"
}

install_sddm() {
	step "Installing the torii SDDM theme"
	sddm_installer="$PREFIX/configs/sddm/themes/torii/install.sh"
	[ -f "$sddm_installer" ] || {
		warn "sddm installer not found in the clone, skipping"
		return 0
	}
	sh "$sddm_installer" || warn "sddm theme install failed"
}

suggest_fish() {
	case "${SHELL:-}" in
	*/fish) ;;
	*)
		say ""
		say "fish is installed but not your login shell. To switch:"
		say "  chsh -s \"\$(command -v fish)\""
		;;
	esac
}

verify() {
	step "Verifying"
	ok=1
	for l in hypr quickshell ghostty; do
		if [ -d "$CFG/$l" ] && [ ! -L "$CFG/$l" ]; then say "  ok   ~/.config/$l"; else
			warn "  miss ~/.config/$l"
			ok=0
		fi
	done
	have qs || {
		warn "  qs (quickshell) not on PATH"
		ok=0
	}
	have Hyprland || warn "  Hyprland not on PATH (install hyprland-git via an AUR helper)"
	[ "$ok" -eq 1 ] || warn "some checks failed, see above"
}

print_next() {
	cat <<EOF

Ricelin is in. From a TTY, start the compositor with:

  Hyprland

Keybinds:
  Super + Return   terminal        Super + C   wallpaper picker
  Super + Space    app launcher    Super + B   shuffle wallpaper
  Super + V        clipboard       Super + L   lock
  Super + E        files           Print       rishot

Update later:   sh "$PREFIX/install.sh"
Remove:         sh "$PREFIX/install.sh" --uninstall
EOF
}

uninstall() {
	step "Removing Ricelin configs"
	for target in \
		"$CFG/hypr" "$CFG/quickshell" "$CFG/ghostty" \
		"$CFG/kdeglobals" "$CFG/systemd/user/hyprland-session.target"; do
		name="$(basename "$target")"
		[ -e "$target" ] || [ -L "$target" ] || continue
		# Only remove what we own. A dest without our marker is the user's own
		# config (or a leftover from another setup); never rm -rf that blindly.
		if ! is_managed "$target"; then
			warn "  skipped $name (not Ricelin-managed, left it alone)"
			continue
		fi
		rm -f "$(marker_for "$target")"
		rm -rf "$target"
		say "  removed $name"
		newest=""
		for b in "$target".bak-ricelin-*; do
			[ -e "$b" ] && newest="$b"
		done
		if [ -n "$newest" ]; then
			mv "$newest" "$target"
			say "  restored backup -> $name"
		fi
	done
	say ""
	say "Configs removed. The clone is still at $PREFIX (rm -rf it to remove fully)."
	say "rishot, fonts and packages were left installed."
}

main() {
	parse_args "$@"

	if [ "$WANT_UNINSTALL" -eq 1 ]; then
		uninstall
		exit 0
	fi

	trap 'restore_tty; printf "\n"; say "Cancelled."; exit 130' INT TERM

	pm="$(detect_pm)"

	interactive_select
	confirm_install

	say ""
	say "Package manager: $pm"

	if [ "$SKIP_DEPS" -eq 0 ]; then
		if [ "$pm" = "pacman" ]; then
			bootstrap_aur_helper && pm="$(detect_pm)"
		fi
		install_deps "$pm" || warn "dependency step incomplete, continuing with the config deploy"
		install_rishot "$pm"
	fi

	deploy
	[ "$SKIP_DEPS" -eq 0 ] && [ "$WANT_SERVICES" -eq 1 ] && enable_services
	[ "$WANT_SDDM" -eq 1 ] && install_sddm

	suggest_fish
	verify
	print_next
}

main "$@"
