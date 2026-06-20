#!/bin/sh
# Ricelin installer.
#
# Pulls the runtime deps, clones the rice into ~/.local/share/ricelin, backs up
# any config it would replace, then symlinks the Ricelin configs into ~/.config.
# Hardware-specific bits (monitor layout, GPU env) are neutralised per machine so
# the rice boots on any setup; the original layout is kept as monitors.lua.example.
#
# Ricelin is a Hyprland shell. On Niri, Sway or anything else only rishot, the
# screenshot tool, runs; this script points you at rishot's own installer there.
#
# Safe to pipe: curl -fsSL .../install.sh | sh
# The whole body lives in main(), called on the last line, so a truncated
# download cannot execute a partial script.

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

# Core deps: the shell, the compositor and everything a Ricelin surface drives.
CORE_PKGS="hyprland-git quickshell ghostty fish \
matugen awww cliphist wl-clipboard imagemagick jq \
brightnessctl playerctl hyprpicker hyprpolkitagent hypridle dotool \
networkmanager bluez bluez-utils pipewire wireplumber pamixer \
kde-cli-tools kdialog fastfetch \
ttf-jetbrains-mono-nerd inter-font noto-fonts noto-fonts-cjk noto-fonts-emoji \
papirus-icon-theme bibata-cursor-theme-bin"

# The daily apps from the stack notes, only with --full.
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
  --uninstall   remove the Ricelin symlinks and restore the newest backup
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

# Resolve a terminal we can talk to even under `curl | sh`, where stdin is the
# script. /dev/tty is the controlling terminal; empty means headless.
tty_dev() {
	if { true </dev/tty; } 2>/dev/null && { true >/dev/tty; } 2>/dev/null; then
		echo /dev/tty
	elif [ -t 0 ]; then
		echo /dev/stdin
	else
		echo ""
	fi
}

# Ask a yes/no question on the terminal. $2 is the default when the user just
# hits enter: Y or N.
ask_yn() {
	_q="$1"
	_def="$2"
	_t="$3"
	printf '  %s ' "$_q" >"$_t"
	read -r _ans <"$_t" || _ans=""
	[ -z "$_ans" ] && _ans="$_def"
	case "$_ans" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# Guided selection. whiptail gives a real tick-box grid when present; otherwise
# we fall back to plain yes/no questions. Either way it reads the terminal, so it
# works through a pipe. Sets WANT_FULL / WANT_SDDM / WANT_SERVICES.
interactive_select() {
	[ "$SELECTION_GIVEN" -eq 1 ] && return 0
	[ "$NO_PROMPT" -eq 1 ] && return 0
	t="$(tty_dev)"
	[ -n "$t" ] || {
		say "No terminal for prompts, taking QuickStart defaults"
		return 0
	}

	if have whiptail; then
		choices=$(whiptail --title "Ricelin installer" \
			--checklist "Space to tick, Enter to install. Leave as-is for QuickStart." 13 66 3 \
			full "Daily apps (dolphin, keepassxc, zathura, imv)" OFF \
			sddm "torii SDDM login theme" OFF \
			services "Enable NetworkManager + bluetooth" ON \
			3>&1 1>&2 2>&3 <"$t") || {
			say "Cancelled."
			exit 0
		}
		WANT_FULL=0
		WANT_SDDM=0
		WANT_SERVICES=0
		case "$choices" in *full*) WANT_FULL=1 ;; esac
		case "$choices" in *sddm*) WANT_SDDM=1 ;; esac
		case "$choices" in *services*) WANT_SERVICES=1 ;; esac
		return 0
	fi

	say ""
	say "Guided install (enter for the default in brackets):"
	ask_yn "Install the daily apps too (dolphin, keepassxc, zathura, imv)? [y/N]" N "$t" && WANT_FULL=1
	ask_yn "Install the torii SDDM login theme? [y/N]" N "$t" && WANT_SDDM=1
	ask_yn "Enable NetworkManager + bluetooth services? [Y/n]" Y "$t" || WANT_SERVICES=0
}

detect_pm() {
	if have yay; then echo yay
	elif have paru; then echo paru
	elif have pacman; then echo pacman
	else echo unknown
	fi
}

# A fresh Arch or CachyOS often ships no AUR helper, but Ricelin needs the AUR
# (hyprland-git, rishot-git, bibata-cursor-theme-bin). Build yay-bin from the AUR
# once so the rest is one command. makepkg refuses to run as root, so this needs a
# normal user; the sudo prompts come from pacman and makepkg themselves.
bootstrap_aur_helper() {
	have yay && return 0
	have paru && return 0
	step "No AUR helper found, bootstrapping yay-bin from the AUR"
	if [ "$(id -u)" -eq 0 ]; then
		warn "run the installer as a normal user (not root); makepkg cannot build as root"
		return 1
	fi
	sudo pacman -S --needed --noconfirm git base-devel || {
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

# Ricelin needs the AUR (hyprland-git, rishot-git, bibata-cursor-theme-bin), so a
# bare pacman cannot pull everything. We say so plainly and install what we can.
install_deps() {
	pm="$1"
	pkgs="$CORE_PKGS"
	[ "$WANT_FULL" -eq 1 ] && pkgs="$pkgs $FULL_PKGS"

	case "$pm" in
	yay | paru)
		step "Installing deps via $pm"
		# word-splitting on $pkgs is intentional: one arg per package.
		# shellcheck disable=SC2086
		"$pm" -S --needed --noconfirm $pkgs || warn "some packages failed; check the log above"
		;;
	pacman)
		step "Installing deps via pacman"
		warn "hyprland-git, rishot-git and bibata-cursor-theme-bin live in the AUR;"
		warn "pacman cannot build them. Install an AUR helper (yay or paru) for the full rice."
		# shellcheck disable=SC2086
		sudo pacman -S --needed --noconfirm $pkgs || warn "some packages failed (AUR ones expected to)"
		;;
	*)
		warn "no supported package manager found"
		say "Install these yourself, then re-run with --no-deps:"
		say "  $CORE_PKGS"
		return 1
		;;
	esac
}

# rishot is its own project with its own installer. Prefer the AUR package, fall
# back to its upstream script so the screenshot key works after the rice is in.
install_rishot() {
	pm="$1"
	if have rishot; then
		say "rishot already present, skipping"
		return 0
	fi
	step "Installing rishot"
	case "$pm" in
	yay | paru)
		"$pm" -S --needed --noconfirm rishot-git && return 0
		warn "AUR rishot-git failed, trying the upstream installer"
		;;
	esac
	if have curl; then
		curl -fsSL "$RISHOT_INSTALL_URL" | sh || warn "rishot install failed; install it yourself for the Print key"
	else
		warn "no curl; install rishot yourself (https://github.com/Gakuseei/rishot)"
	fi
}

# Move an existing path out of the way before we symlink over it. A path that is
# already our own symlink is left alone so re-runs do not pile up backups.
backup_path() {
	target="$1"
	[ -e "$target" ] || [ -L "$target" ] || return 0
	link_dest=""
	[ -L "$target" ] && link_dest="$(readlink "$target")"
	case "$link_dest" in
	"$PREFIX"/*) return 0 ;;
	esac
	backup="${target}.bak-ricelin-$(date +%Y%m%d-%H%M%S)"
	mv "$target" "$backup"
	say "  backed up $(basename "$target") -> $(basename "$backup")"
}

link_into_config() {
	src="$1"
	dest="$2"
	[ -e "$src" ] || {
		warn "missing in clone: $src"
		return 0
	}
	mkdir -p "$(dirname "$dest")"
	backup_path "$dest"
	ln -sfn "$src" "$dest"
	say "  linked $(basename "$dest")"
}

# Replace the hardware-specific files in the clone with portable versions. The
# clone is per-user under $PREFIX, so this never touches a hand-tuned setup; the
# original monitor layout is preserved next to it as a reference.
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

	step "Linking configs into $CFG"
	link_into_config "$PREFIX/configs/hypr" "$CFG/hypr"
	link_into_config "$PREFIX/configs/quickshell" "$CFG/quickshell"
	link_into_config "$PREFIX/configs/ghostty" "$CFG/ghostty"
	link_into_config "$PREFIX/configs/kde/kdeglobals" "$CFG/kdeglobals"
	link_into_config "$PREFIX/configs/systemd/user/hyprland-session.target" \
		"$CFG/systemd/user/hyprland-session.target"

	mkdir -p "$HOME/.cache/ricelin"
}

# NetworkManager and bluetooth back the Link surface. Enabling NetworkManager on
# a box already using iwd or systemd-networkd would break its network, so we only
# touch it when nothing else is driving the link.
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
		if [ -L "$CFG/$l" ]; then say "  ok   ~/.config/$l"; else
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
	step "Removing Ricelin symlinks"
	for name in hypr quickshell ghostty kdeglobals; do
		target="$CFG/$name"
		if [ -L "$target" ]; then
			dest="$(readlink "$target")"
			case "$dest" in
			"$PREFIX"/*)
				rm "$target"
				say "  removed $name"
				newest=""
				for b in "$target".bak-ricelin-*; do
					[ -e "$b" ] && newest="$b"
				done
				if [ -n "$newest" ]; then
					mv "$newest" "$target"
					say "  restored backup -> $name"
				fi
				;;
			esac
		fi
	done
	target="$CFG/systemd/user/hyprland-session.target"
	[ -L "$target" ] && rm "$target" && say "  removed hyprland-session.target"
	say ""
	say "Configs unlinked. The clone is still at $PREFIX (rm -rf it to remove fully)."
	say "rishot, fonts and packages were left installed."
}

main() {
	parse_args "$@"

	if [ "$WANT_UNINSTALL" -eq 1 ]; then
		uninstall
		exit 0
	fi

	say ""
	say "  Ricelin"
	say "  Hyprland shell installer"
	say ""

	pm="$(detect_pm)"
	say "Package manager: $pm"

	interactive_select

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
