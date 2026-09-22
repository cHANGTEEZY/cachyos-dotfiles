#!/usr/bin/env bash
# Restore this CachyOS Hyprland rice: packages, keybinds, and config symlinks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YES=0
CONFIGS_ONLY=0
FULL=0

usage() {
    cat <<EOF
Usage: ./install.sh [options]

  (default)        Install the Hyprland rice packages, then symlink configs
  --configs-only   Skip packages and only link configs
  --full           Also install every explicitly installed package from this machine
  --yes            Do not ask for confirmation
  -h, --help       Show this help

Existing files and directories are moved to <name>.bak.<timestamp> before linking.
Configs are symlinked, so later edits in this repo apply immediately.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) YES=1 ;;
        --configs-only) CONFIGS_ONLY=1 ;;
        --full) FULL=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ ! -r /etc/os-release ]]; then
    echo "This installer is for CachyOS or Arch." >&2
    exit 1
fi

# shellcheck disable=SC1091
os_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
if [[ "$os_id" != "cachyos" && "$os_id" != "arch" ]]; then
    echo "This installer is for CachyOS or Arch (found: ${os_id:-unknown})." >&2
    exit 1
fi

if [[ "$YES" -eq 0 ]]; then
    echo "Install Hyprland rice from: $ROOT"
    echo "Target home: $HOME"
    if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
        echo "Packages: desktop rice$([[ "$FULL" -eq 1 ]] && echo " + full explicit list")"
    else
        echo "Packages: skipped"
    fi
    echo "Existing configs will be backed up, then replaced with symlinks."
    read -r -p "Continue? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

read_packages() {
    local file="$1"
    grep -vE '^[[:space:]]*(#|$)' "$file"
}

install_pacman_list() {
    local file="$1"
    local -a pkgs=()
    local pkg
    while IFS= read -r pkg; do
        if [[ "$os_id" != "cachyos" && "$pkg" == cachyos-* ]]; then
            echo "skip (CachyOS only): $pkg"
            continue
        fi
        pkgs+=("$pkg")
    done < <(read_packages "$file")

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    local -a flags=(--needed)
    if [[ "$YES" -eq 1 ]]; then
        flags+=(--noconfirm)
    fi
    sudo pacman -S "${flags[@]}" "${pkgs[@]}"
}

install_aur_list() {
    local file="$1"
    local -a pkgs=()
    local pkg
    while IFS= read -r pkg; do
        pkgs+=("$pkg")
    done < <(read_packages "$file")

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    if ! command -v yay >/dev/null 2>&1; then
        echo "yay is required to install AUR packages:" >&2
        printf '  %s\n' "${pkgs[@]}" >&2
        echo "Install yay, then run this script again." >&2
        exit 1
    fi

    local -a flags=(--needed --answerdiff None --answerclean None)
    if [[ "$YES" -eq 1 ]]; then
        flags+=(--noconfirm)
    fi
    yay -S "${flags[@]}" "${pkgs[@]}"
}

if [[ "$CONFIGS_ONLY" -eq 0 ]]; then
    echo "Installing desktop packages..."
    install_pacman_list "$ROOT/packages/desktop.txt"
    echo "Installing AUR packages..."
    install_aur_list "$ROOT/packages/aur.txt"

    if [[ "$FULL" -eq 1 ]]; then
        echo "Installing the full explicit package set from this machine..."
        install_pacman_list "$ROOT/packages/explicit-pacman.txt" || {
            echo "Some official packages from the snapshot are no longer in the repos." >&2
            echo "The rice packages above are already installed. Edit packages/explicit-pacman.txt and retry --full." >&2
            exit 1
        }
        install_aur_list "$ROOT/packages/explicit-aur.txt"
    fi
fi

link_path() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        local current
        current="$(readlink -f "$dest" || true)"
        local wanted
        wanted="$(readlink -f "$src")"
        if [[ "$current" == "$wanted" ]]; then
            echo "linked  $dest"
            return 0
        fi
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
        mv "$dest" "$backup"
        echo "backup  $dest -> $backup"
    fi

    ln -sfn "$src" "$dest"
    echo "linked  $dest -> $src"
}

echo "Linking configs..."
for src in "$ROOT"/config/*; do
    [[ -e "$src" ]] || continue
    link_path "$src" "$HOME/.config/$(basename "$src")"
done

for src in "$ROOT"/home/.[!.]*; do
    [[ -e "$src" ]] || continue
    link_path "$src" "$HOME/$(basename "$src")"
done

link_path "$ROOT/share/icons/Madara-Kunai" "$HOME/.local/share/icons/Madara-Kunai"

mkdir -p "$HOME/Pictures/Wallpapers"
chmod +x "$ROOT"/config/hypr/scripts/*.sh "$ROOT"/config/hypr/scripts/*.py \
    "$ROOT"/config/waybar/scripts/* \
    "$ROOT"/config/quickshell/hyprquickpaper/*.sh 2>/dev/null || true

cat <<EOF

Rice linked.

Before the first login on a new machine, edit the monitor in:
  $ROOT/config/hypr/hyprland.lua
  MONITOR1, mode, and position (this machine uses DP-1 at 2560x1440@170).

Wallpapers are not in this repo. Copy them to:
  $HOME/Pictures/Wallpapers
The lock screen expects:
  $HOME/Pictures/Wallpapers/wallhaven-72qq29.png

Then log out and start Hyprland (UWSM session).
EOF
