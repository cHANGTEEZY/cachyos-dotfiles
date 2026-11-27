#!/bin/bash
# Toggle the Omarchy-style command palette. The shell stays running so the
# next Super+Space is instant.

if ! pgrep -u "$USER" -f -- '-c commandspace([[:space:]]|$)' >/dev/null; then
    setsid -f qs -c commandspace >/dev/null 2>&1
    for _ in $(seq 1 50); do
        qs -c commandspace ipc call commandspace ping >/dev/null 2>&1 && break
        sleep 0.02
    done
fi

exec qs -c commandspace ipc call commandspace toggle
