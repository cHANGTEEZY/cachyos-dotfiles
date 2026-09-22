awww img "$1" -t random --transition-duration 1
ln -sfn "$1" "$HOME/.config/hypr/lock-wallpaper"
sed -i "s|^    path = .*|    path = $1|" "$HOME/.config/hypr/hyprlock.conf"
