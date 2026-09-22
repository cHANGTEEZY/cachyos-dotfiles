-- 43PR Hyprland rice (https://github.com/43PR/dotfiles)
-- This is the only Hyprland config. HyprMod overlay is not loaded.
-- Machine-specific apps, monitor, input, and keybinds are kept.

---- APPS / HARDWARE ----

mainMod      = "SUPER"
TERMINAL     = "alacritty"
FILE_MANAGER = "dolphin"
BROWSER      = "zen-browser"
EDITOR       = "gnome-text-editor --new-window"
CALCULATOR   = "gnome-calculator"
terminal     = TERMINAL
fileManager  = FILE_MANAGER
browser      = BROWSER
menu         = "rofi -show drun"

MONITOR1 = "DP-1"
PRIMARY_MONITOR = MONITOR1
NUM_WPM = 9

---- MONITOR ----

hl.monitor({
    output    = MONITOR1,
    mode      = "2560x1440@170",
    position  = "0x0",
    scale     = "1",
})

---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("waybar")
    hl.exec_cmd("qs -c workspacebar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("xhost +SI:localuser:root")
end)

---- INPUT ----

hl.config({
    input = {
        follow_mouse = 1,
        sensitivity = -0.3,
        accel_profile = "flat",
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })

---- LOOK AND FEEL (43PR) ----

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 3,
        border_size = 0,
        extend_border_grab_area = 10,
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        dim_special = 0.3,
        active_opacity = 1,
        inactive_opacity = 1,
        fullscreen_opacity = 1,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            special = true,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "default" })

hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 3,
        allow_session_lock_restore = true,
        session_lock_xray = false,
        focus_on_activate = true,
        middle_click_paste = false,
    },
    xwayland = {
        force_zero_scaling = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

---- SPLIT-OUT FILES ----

require("keybinds")
require("rules")

-- HyprMod managed settings
require("hyprland-gui")
