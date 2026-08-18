#!/usr/bin/env bash

INTERNAL="eDP"
EXTERNAL="HDMI-A-0"
CACHE_DIR="$HOME/.cache/bspwm"
STATE_FILE="$CACHE_DIR/external-apps"
LOCK_FILE="$CACHE_DIR/monitor-hotplug.lock"
LOG_FILE="$CACHE_DIR/monitor-hotplug.log"

mkdir -p "$CACHE_DIR"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"; }

# Single instance guard: exit if another daemon is already running
if [ -f "$LOCK_FILE" ]; then
    if kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
        log "JA EXISTE um daemon (PID $(cat "$LOCK_FILE")). Saindo."
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

trap 'rm -f "$LOCK_FILE"' EXIT

ext_connected() { xrandr --query | grep -q "^$EXTERNAL connected"; }

on_disconnect() {
    log "DISCONNECT - migrando janelas de $EXTERNAL para $INTERNAL"
    ext_desks=($(bspc query -D -m "$EXTERNAL" 2>/dev/null))
    int_desks=($(bspc query -D -m "$INTERNAL" 2>/dev/null))
    : > "$STATE_FILE"
    for i in "${!ext_desks[@]}"; do
        d="${ext_desks[$i]}"
        target="${int_desks[$i]:-${int_desks[0]}}"
        for w in $(bspc query -N -d "$d" -n .window 2>/dev/null); do
            class=$(bspc query -T -n "$w" 2>/dev/null | grep -o '"className":"[^"]*"' | head -1 | cut -d'"' -f4)
            echo "$w $class $((i+1))" >> "$STATE_FILE"
            log "  movendo $w ($class) desktop $((i+1)) -> $INTERNAL"
            bspc node "$w" --to-desktop "$target" 2>/dev/null
        done
    done
    bspc monitor -f "$INTERNAL"
    xrandr --output "$EXTERNAL" --off
    log "DISCONNECT concluido. $(wc -l < "$STATE_FILE") janelas salvas."
}

on_connect() {
    log "CONNECT - restaurando janelas para $EXTERNAL"
    xrandr --output "$EXTERNAL" --auto --right-of "$INTERNAL"
    for n in $(seq 1 10); do
        if [ -z "$(bspc query -D -m "$EXTERNAL" 2>/dev/null)" ]; then
            bspc monitor "$EXTERNAL" -d 1 2 3 4 5 6 2>/dev/null || { sleep 0.5; continue; }
        fi
        break
    done
    while read -r w class idx; do
        [ -z "$w" ] && continue
        bspc query -N -n "$w" >/dev/null 2>&1 || { log "  janela $w nao existe mais. pulando."; continue; }
        log "  restaurando $w ($class) -> $EXTERNAL:^$idx"
        bspc node "$w" --to-desktop "$EXTERNAL:^$idx" 2>/dev/null
    done < "$STATE_FILE"
    rm -f "$STATE_FILE"
    log "CONNECT concluido."
}

if ext_connected; then
    prev="connected"
    log "Iniciado com $EXTERNAL conectado."
else
    prev="disconnected"
    [ -n "$(bspc query -D -m "$EXTERNAL" 2>/dev/null)" ] && on_disconnect
    log "Iniciado com $EXTERNAL desconectado."
fi

while :; do
    if ext_connected; then cur="connected"; else cur="disconnected"; fi
    if [ "$cur" != "$prev" ]; then
        log "Transicao: $prev -> $cur"
        if [ "$cur" = "disconnected" ]; then on_disconnect; else on_connect; fi
        prev="$cur"
    fi
    sleep 1
done
