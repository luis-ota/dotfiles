#!/usr/bin/env bash

INTERNAL="eDP"
EXTERNAL="HDMI-A-0"
STATE_FILE="$HOME/.cache/bspwm/external-apps"
mkdir -p "$(dirname "$STATE_FILE")"

ext_connected() { xrandr --query | grep -q "^$EXTERNAL connected"; }

on_disconnect() {
    : > "$STATE_FILE"
    ext_desks=($(bspc query -D -m "$EXTERNAL" 2>/dev/null))
    int_desks=($(bspc query -D -m "$INTERNAL" 2>/dev/null))
    for i in "${!ext_desks[@]}"; do
        d="${ext_desks[$i]}"
        target="${int_desks[$i]:-${int_desks[0]}}"
        for w in $(bspc query -N -d "$d" -n .window 2>/dev/null); do
            class=$(bspc query -T -n "$w" | grep -o '"className":"[^"]*"' | head -1 | cut -d'"' -f4)
            echo "$w $class $((i+1))" >> "$STATE_FILE"
            bspc node "$w" --to-desktop "$target" 2>/dev/null
        done
    done
    bspc monitor -f "$INTERNAL"
    xrandr --output "$EXTERNAL" --off
}

on_connect() {
    xrandr --output "$EXTERNAL" --auto --right-of "$INTERNAL"
    for n in $(seq 1 10); do
        if [ -z "$(bspc query -D -m "$EXTERNAL" 2>/dev/null)" ]; then
            bspc monitor "$EXTERNAL" -d 1 2 3 4 5 6 2>/dev/null || { sleep 0.5; continue; }
        fi
        break
    done
    while read -r w class idx; do
        [ -z "$w" ] && continue
        bspc query -N -n "$w" >/dev/null 2>&1 || continue
        bspc node "$w" --to-desktop "$EXTERNAL:^$idx" 2>/dev/null
    done < "$STATE_FILE"
    rm -f "$STATE_FILE"
}

if ext_connected; then
    prev="connected"
else
    prev="disconnected"
    [ -n "$(bspc query -D -m "$EXTERNAL" 2>/dev/null)" ] && on_disconnect
fi

while :; do
    if ext_connected; then cur="connected"; else cur="disconnected"; fi
    if [ "$cur" != "$prev" ]; then
        if [ "$cur" = "disconnected" ]; then on_disconnect; else on_connect; fi
        prev="$cur"
    fi
    sleep 1
done