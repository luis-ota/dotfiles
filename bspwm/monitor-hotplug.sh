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

# Migra janelas do EXTERNAL para o INTERNAL, salvando o estado.
# Retorna 0 se salvou alguma janela.
migrate_to_internal() {
    ext_desks=($(bspc query -D -m "$EXTERNAL" 2>/dev/null))
    [ ${#ext_desks[@]} -eq 0 ] && return 1
    int_desks=($(bspc query -D -m "$INTERNAL" 2>/dev/null))
    entries=()
    for i in "${!ext_desks[@]}"; do
        d="${ext_desks[$i]}"
        target="${int_desks[$i]:-${int_desks[0]}}"
        for w in $(bspc query -N -d "$d" -n .window 2>/dev/null); do
            [ -z "$w" ] && continue
            class=$(bspc query -T -n "$w" 2>/dev/null | grep -o '"className":"[^"]*"' | head -1 | cut -d'"' -f4)
            entries+=("$w $class $((i+1))")
            log "  movendo $w ($class) desktop $((i+1)) -> $INTERNAL"
            bspc node "$w" --to-desktop "$target" 2>/dev/null
        done
    done
    # So truncar/gravar o state file se houver janelas (o rescue_stranded
    # roda periodicamente e nao pode apagar o estado ja salvo).
    if [ ${#entries[@]} -gt 0 ]; then
        printf '%s\n' "${entries[@]}" > "$STATE_FILE"
        return 0
    fi
    return 1
}

on_disconnect() {
    log "DISCONNECT - migrando janelas de $EXTERNAL para $INTERNAL"
    # Retenta por alguns segundos: na transicao o bspwm pode ainda nao
    # ter os desktops do monitor fantasma prontos.
    for attempt in $(seq 1 10); do
        if migrate_to_internal; then break; fi
        sleep 0.5
    done
    bspc monitor -f "$INTERNAL"
    xrandr --output "$EXTERNAL" --off
    log "DISCONNECT concluido. $(wc -l < "$STATE_FILE" 2>/dev/null || echo 0) janelas salvas."
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

# Resgate periodico: mesmo sem transicao detectada (ex: monitor sem energia
# mas cabo plugado), move janelas presas em desktops de monitor sem sinal.
rescue_stranded() {
    ext_desks=($(bspc query -D -m "$EXTERNAL" 2>/dev/null))
    [ ${#ext_desks[@]} -eq 0 ] && return
    if migrate_to_internal; then
        log "RESGATE: $(wc -l < "$STATE_FILE") janela(s) presas movidas para $INTERNAL"
        bspc monitor -f "$INTERNAL"
    fi
}

if ext_connected; then
    prev="connected"
    log "Iniciado com $EXTERNAL conectado."
else
    prev="disconnected"
    rescue_stranded
    log "Iniciado com $EXTERNAL desconectado."
fi

counter=0
while :; do
    if ext_connected; then cur="connected"; else cur="disconnected"; fi
    if [ "$cur" != "$prev" ]; then
        log "Transicao: $prev -> $cur"
        if [ "$cur" = "disconnected" ]; then on_disconnect; else on_connect; fi
        prev="$cur"
        counter=0
    else
        # Sem mudanca de estado: a cada ~5s verifica janelas presas.
        counter=$((counter + 1))
        if [ "$cur" = "disconnected" ] && [ $counter -ge 5 ]; then
            rescue_stranded
            counter=0
        fi
    fi
    sleep 1
done