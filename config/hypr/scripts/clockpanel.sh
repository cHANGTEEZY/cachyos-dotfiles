#!/bin/bash
# Toggle the calendar and world-clock panel. The shell stays running so the
# next click is instant.

if ! pgrep -u "$USER" -f -- '-c clockpanel([[:space:]]|$)' >/dev/null; then
    setsid -f qs -c clockpanel >/dev/null 2>&1
    for _ in $(seq 1 50); do
        qs -c clockpanel ipc call clockpanel ping >/dev/null 2>&1 && break
        sleep 0.02
    done
fi

exec qs -c clockpanel ipc call clockpanel toggle
