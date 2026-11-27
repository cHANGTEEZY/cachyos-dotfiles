-- ~/.config/hypr/rules.lua
-- Migrated from rules.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Keep the workspace switcher above waybar. It hides itself in fullscreen.
hl.layer_rule({
    name = "workspace-switcher-above-bar",
    match = { namespace = "^changteezy-workspaces$" },
    order = 20,
})

-- Command palette sits above the bar and the workspace switcher.
hl.layer_rule({
    name = "commandspace-overlay",
    match = { namespace = "^commandspace$" },
    order = 50,
})

-- Calendar and world clock, opened from the center clock.
hl.layer_rule({
    name = "clockpanel-overlay",
    match = { namespace = "^clockpanel$" },
    order = 60,
})

-- Toggles beside the clock. Above the bar, under the command palette.
hl.layer_rule({
    name = "indicators-overlay",
    match = { namespace = "^changteezy-indicators$" },
    order = 25,
})

-- Omarchy keeps normal windows solid. Fullscreen stays opaque.
hl.window_rule({
    name = "solid-windows",
    match = { class = ".*" },
    opacity = "1.0 override 1.0 override 1.0 override",
    opaque = true,
    no_blur = true,
    force_rgbx = false,
})

-- Terminals use Omarchy's slight active/inactive transparency.
hl.window_rule({
    name = "terminal-transparency",
    match = { class = "^(Alacritty|kitty|foot|org\\.wezfurlong\\.wezterm|com\\.mitchellh\\.ghostty)$" },
    opacity = "0.985 override 0.96 override 1.0 override",
    opaque = false,
    no_blur = true,
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
