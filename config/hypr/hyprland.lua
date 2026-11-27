-- 43PR Hyprland rice (https://github.com/43PR/dotfiles)
-- This is the only Hyprland config. HyprMod overlay is not loaded.
-- Machine-specific apps, monitor, input, and keybinds are kept.

---- APPS / HARDWARE ----

mainMod      = "SUPER"
TERMINAL     = "alacritty"
FILE_MANAGER = "dolphin"
BROWSER      = "brave"
EDITOR       = "gnome-text-editor --new-window"
CALCULATOR   = "gnome-calculator"
terminal     = TERMINAL
fileManager  = FILE_MANAGER
browser      = BROWSER
menu         = os.getenv("HOME") .. "/.config/hypr/scripts/commandspace.sh"

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
    hl.exec_cmd("qs -c commandspace")
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

---- LOOK AND FEEL ----
-- Motion and spacing follow Omarchy's default Hyprland rice
-- (omacom/omarchy default/hypr/looknfeel.lua): square windows, open gaps,
-- a 2px gradient border, no blur or shadow, a short pop-in, and instant
-- workspace switches.

local active_border_color = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }
local inactive_border_color = "rgba(595959aa)"

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = active_border_color,
            inactive_border = inactive_border_color,
        },
        extend_border_grab_area = 8,
        resize_on_border = true,
        hover_icon_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 0,
        dim_special = 0.3,
        active_opacity = 1,
        inactive_opacity = 1,
        fullscreen_opacity = 1,
        blur = { enabled = false },
        shadow = { enabled = false },
    },
    animations = { enabled = true },
    group = {
        col = {
            border_active = active_border_color,
            border_inactive = inactive_border_color,
        },
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global",       enabled = true,  speed = 8,    bezier = "default" })
hl.animation({ leaf = "border",       enabled = true,  speed = 4.31, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",      enabled = true,  speed = 3.03, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",    enabled = true,  speed = 3.28, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",   enabled = true,  speed = 1.19, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",       enabled = true,  speed = 1.38, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",      enabled = true,  speed = 1.17, bezier = "almostLinear" })
hl.animation({ leaf = "fade",         enabled = true,  speed = 2.42, bezier = "quick" })
hl.animation({ leaf = "fadeSwitch",   enabled = false })
hl.animation({ leaf = "layers",       enabled = true,  speed = 3.05, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",     enabled = true,  speed = 3.2,  bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",    enabled = true,  speed = 1.2,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true,  speed = 1.43, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut",enabled = true,  speed = 1.11, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",   enabled = false })

hl.config({
    dwindle = {
        preserve_split = true,
        force_split = 2,
    },
})
hl.config({
    master = { new_status = "master" },
})

hl.config({
    misc = {
        background_color = "rgb(000000)",
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        vrr = 3,
        allow_session_lock_restore = true,
        session_lock_xray = false,
        focus_on_activate = true,
        middle_click_paste = false,
    },
    cursor = {
        hide_on_key_press = true,
        warp_on_change_workspace = 1,
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

-- Keep Omarchy's border after HyprMod, which sets its own border size and color.
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = active_border_color,
            inactive_border = inactive_border_color,
        },
    },
})
