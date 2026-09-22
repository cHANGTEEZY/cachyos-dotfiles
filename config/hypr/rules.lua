-- ~/.config/hypr/rules.lua
-- Migrated from rules.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Keep the workspace switcher above waybar, but on the top layer so
-- exclusive fullscreen windows (games) cover it.
hl.layer_rule({
    match = { namespace = "changteezy-workspaces" },
    order = 10,
})

-- Give regular windows subtle compositor transparency. Fullscreen windows
-- remain opaque, and force_rgbx stays disabled to avoid broken overlays.
hl.window_rule({
    name = "subtle-transparency",
    match = { class = ".*" },
    opacity = "0.96 override 0.92 override 1.0 override",
    opaque = true,
    no_blur = true,
    force_rgbx = false,
})

-- Terminals keep only their own configured alpha (e.g. Alacritty at 0.8).
hl.window_rule({
    name = "glass-terminals",
    match = { class = "^(Alacritty|kitty|foot|org\\.wezfurlong\\.wezterm|com\\.mitchellh\\.ghostty)$" },
    opacity = "1.0 override 1.0 override 1.0 override",
    opaque = false,
    no_blur = false,
})

-- Terminal screensaver: cover the monitor edge-to-edge with no window chrome.
hl.window_rule({
    name = "fullscreen-screensaver",
    match = { class = "^org\\.changteezy\\.screensaver$" },
    fullscreen = true,
    fullscreen_state = "2 2",
    float = true,
    pin = true,
    stay_focused = true,
    size = { "monitor_w", "monitor_h" },
    move = "0 0",
    animation = "none",
    rounding = 0,
    border_size = 0,
    no_shadow = true,
    decorate = false,
    opacity = "1.0 override 1.0 override 1.0 override",
    opaque = true,
    no_blur = true,
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})
