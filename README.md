<div align="center">

# Ricelin

**My Hyprland setup on CachyOS. The whole shell is hand-written Quickshell, no copied dotfiles.**

![Ricelin desktop](assets/hero.png)

</div>

I started this a few months into Linux, mostly to learn how things work. It somehow turned into my daily driver.

## The shell

Everything you see is hand-written Quickshell. One pill bar that morphs into whatever surface I need.

![The pill surfaces](assets/shell.png)

The pill becomes media and now playing, a calendar, the wallpaper picker, clipboard history, an audio and brightness mixer, and network and bluetooth controls. There is also an app launcher, a lock screen, and rishot, my own screenshot and annotation tool.

## Stack

- WM: Hyprland, configured in Lua
- Shell UI: custom Quickshell
- Terminal: Ghostty
- Shell: fish
- Font: JetBrains Mono Nerd
- Colors: wallust, palette pulled from the wallpaper

wallust reads a palette from each wallpaper and recolors the terminal, window borders and fastfetch. The shell itself runs a warm vermilion theme I tuned by hand.

<div align="center">

![wallust pulls the palette from the wallpaper](assets/wallust.gif)

![Wallpaper retheme](assets/retheme.gif)

</div>

## Install

Arch or CachyOS. If you have no AUR helper it builds yay for you:

```sh
curl -fsSL https://raw.githubusercontent.com/Gakuseei/Ricelin/main/install.sh | sh
```

Run it and it walks you through a short menu: tick the daily apps, the SDDM theme
and the services you want, or just hit enter for QuickStart. It works straight
through the pipe, reading your answers from the terminal.

It then pulls the deps, clones the rice into `~/.local/share/ricelin` and symlinks
the configs into `~/.config`, backing up anything it would replace. The monitor
layout and GPU env are swapped for portable defaults, so it boots on any hardware;
my own layout is kept next to it as `monitors.lua.example`. Then start `Hyprland`
from a TTY.

To skip the menu:

```
--quickstart  core defaults, no questions
--full        also install the daily apps (dolphin, keepassxc, zathura, imv, rnote)
--sddm        also install the torii SDDM login theme
--no-prompt   take defaults, for headless or CI
--uninstall   remove the symlinks and restore the newest backup
```

Ricelin is a Hyprland shell. On Niri, Sway or anything else, only rishot (the
screenshot tool) runs; the installer points you at [rishot](https://github.com/Gakuseei/rishot)'s own installer there.

## Keybinds

| Key | Action |
|---|---|
| `Super` + `Return` | terminal |
| `Super` + `Space` | app launcher |
| `Super` + `V` | clipboard history |
| `Super` + `C` | wallpaper picker |
| `Super` + `B` | shuffle wallpaper and retheme |
| `Super` + `E` | file manager |
| `Super` + `T` | toggle floating |
| `Super` + `L` | lock |
| `Print` | rishot |

## Notes

These started as my personal dotfiles, built around my own machine. The installer neutralises the hardware-specific bits, but some paths and choices still lean on how I run things, so read before you borrow.

## Credits

The lock screen, the SDDM background and the wallpapers are not mine. See [CREDITS](configs/sddm/themes/torii/CREDITS.md).
