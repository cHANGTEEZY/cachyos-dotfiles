#!/bin/bash
# hypridle calls this instead of locking or sleeping directly, so Stay awake
# can skip those actions without stopping the idle daemon.

flag="${XDG_STATE_HOME:-$HOME/.local/state}/changteezy/indicators/caffeine"
if [[ -f "$flag" ]]; then
    exit 0
fi

case "${1:-}" in
    screensaver)
        exec "$HOME/.config/hypr/scripts/launch-screensaver.sh"
        ;;
    lock)
        exec loginctl lock-session
        ;;
    dpms-off)
        exec hyprctl dispatch 'hl.dsp.dpms({action = "disable"})'
        ;;
    suspend)
        systemctl suspend || loginctl suspend
        ;;
    *)
        exit 1
        ;;
esac
