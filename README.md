# CachyOS Hyprland dotfiles

Personal Hyprland rice for CachyOS. Snapshot taken from the machine that runs Hyprland 0.56.2 under UWSM.

The desktop is a [43PR](https://github.com/43PR/dotfiles) Hyprland Lua config with local apps, a single 1440p monitor, Waybar, a Quickshell workspace bar, Rofi, and a hyprlock screen.

## Install

On a fresh CachyOS (or Arch) install:

```bash
git clone https://github.com/changteezy/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` installs the rice packages, then symlinks this repo into `~/.config`, `~`, and the Madara-Kunai cursor theme. Anything already in the way is moved to `name.bak.<timestamp>`.

```bash
./install.sh --configs-only   # link configs, skip packages
./install.sh --full           # also install every explicit package from this machine
./install.sh --yes            # skip the confirmation prompt
```

Before the first login on another computer, edit the monitor in `config/hypr/hyprland.lua`. This machine uses `DP-1` at `2560x1440@170`.

Wallpapers are not in the repo. Put them in `~/Pictures/Wallpapers`. The lock screen looks for `~/Pictures/Wallpapers/wallhaven-72qq29.png` until you pick another one with Super+Shift+W.

Log out and start the Hyprland UWSM session.

## This setup

| Piece | Choice |
| --- | --- |
| Session | Hyprland 0.56.2, UWSM |
| Mod key | Super |
| Terminal | Alacritty (JetBrainsMono Nerd Font, opacity 0.8) |
| File manager | Dolphin |
| Browser | Zen (`zen-browser-bin`) |
| Editor shortcut | GNOME Text Editor |
| Calculator | GNOME Calculator |
| Launcher | Rofi |
| Bar | Waybar on top, Quickshell workspace bar |
| Notifications | dunst |
| Power menu | wlogout |
| Wallpaper | `awww`, picker is Quickshell hyprquickpaper |
| Lock | hyprlock, idle via hypridle |
| Shell | zsh + Powerlevel10k (`cachyos-zsh-config`) |
| GTK | Adwaita, dark, Papirus-Dark icons, Madara-Kunai cursor (48) |
| Layout | dwindle, 3px gaps, 8px rounding, blur on |

`packages/explicit-pacman.txt` and `packages/explicit-aur.txt` are the full explicitly installed lists from this machine. `./install.sh --full` installs those too. The default run only installs `packages/desktop.txt` and `packages/aur.txt`.

AUR packages that were installed but are not started by this rice (Caelestia, WhiteSur, bun, and the extra fonts) stay in `packages/explicit-aur.txt`.

## Keybindings

Super is the main modifier. Workspaces 1–9 are the number row. `0` is workspace 10 in the loops, and this config sets `NUM_WPM` to 9, so keys 1–9 are the ones in use.

### Windows

| Keys | Action |
| --- | --- |
| Super + Q | Close window |
| Super + Escape | Kill the Hyprland client |
| Super + arrows | Move focus |
| Super + Shift + arrows | Move window |
| Super + Alt + Space | Float |
| Super + F | Fullscreen |
| Super + D | Maximize |
| Super + J | Toggle split |
| Super + mouse drag | Move window |
| Super + right click drag | Resize window |
| Alt + Tab / Super + Tab | Next window |
| Super + Minus / Plus | Cursor zoom |

### Launchers

| Keys | Action |
| --- | --- |
| Super + Return | Alacritty |
| Super + E | Dolphin |
| Super + T | GNOME Text Editor |
| Super + W | Zen (focus the existing window if it is already open) |
| Super + C | Calculator |
| Super + Space | Command menu (apps and commands) |
| Super + Period | Rofi emoji |
| Super + V | Clipboard history (cliphist + Rofi) |
| Super + X | PulseAudio volume control |
| Super + Z | Toggle opacity |
| Ctrl + Shift + Escape | btop |

### Workspaces

| Keys | Action |
| --- | --- |
| Super + 1–9 | Focus workspace |
| Super + Shift + 1–9 | Move window to workspace |
| Super + Ctrl + Left / Right | Previous / next workspace |
| Super + Ctrl + Down | Empty workspace on this monitor |
| Super + scroll | Previous / next workspace |
| Super + Shift + S | Toggle the scratchpad |
| Super + Ctrl + S | Send window to the scratchpad |

### Capture, theme, session

| Keys | Action |
| --- | --- |
| Super + S / Print | Screenshot a region to the clipboard |
| Super + Print | Screenshot the active monitor |
| Super + P | Color picker (`hyprpicker`) |
| Super + Shift + W | Wallpaper picker |
| Super + Alt + W | Toggle Waybar |
| Super + A | Pop the last notification |
| Super + L | Lock |
| Super + Shift + L | Preview the screensaver |
| Super + Alt + C | Power menu |

Media keys, volume, and brightness keys are bound too. Four-finger horizontal swipe changes workspace. Three-finger down closes, up fullscreens, left floats.

## Layout

```
config/          linked to ~/.config
  hypr/          Hyprland Lua config, keybinds, rules, lock, idle, scripts
  waybar/        top bar
  quickshell/    workspace bar, command menu, wallpaper picker
  rofi/ dunst/ wlogout/ alacritty/ kitty/ fuzzel/
  gtk-3.0/ gtk-4.0/ btop/ cava/ fish/ fontconfig/
home/            .zshrc .zprofile .p10k.zsh .gtkrc-2.0 .gitconfig
share/icons/     Madara-Kunai cursor theme
packages/        pacman and AUR lists
install.sh
```

## Left out on purpose

- Wallpapers (`~/Pictures/Wallpapers`, about 126 MB)
- Browser, Discord, Cursor, and Steam profiles
- Neovim. `~/.config/nvim` is a broken symlink to `~/Developer/neovim-config-ctz`, and that directory is not on this machine
- Caches, history, and `__pycache__`

`home/.gitconfig` contains the git name `changteezy` and email `JAGATGURUNG30@GMAIL.COM`. Delete that file before publishing if you do not want the address in the repo.

## Publish

From this directory, after `gh auth login`:

```bash
gh repo create dotfiles --public --source=. --remote=origin --push
```
