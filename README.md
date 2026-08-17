# dotfiles

Configurações e scripts do meu sistema Arch Linux + bspwm.

## Estrutura

```
bspwm/
  monitor-hotplug.sh    Migra apps entre notebook e monitor externo ao plugar/desplugar HDMI
scripts/
  check_bluetooth_device_info   Avisa quando bateria de dispositivo Bluetooth está baixa
  check_idle                    Trava a tela após 5min ocioso (sem áudio)
  hibernate_if_idle             Suspende/armazena conforme idle e bateria
  wallpaper/
    change_wallpapers.sh        Troca o wallpaper de cada monitor (nitrogen)
```

## Uso

### monitor-hotplug.sh

Daemon que roda em background (iniciado pelo `bspwmrc`):

- **Desconectou HDMI** → move todas as janelas do monitor externo para o notebook
- **Conectou HDMI** → devolve **apenas** as janelas que vieram do monitor

Ajuste `INTERNAL`/`EXTERNAL` conforme seus monitores (`xrandr`).

### Scripts de idle/wallpaper/bluetooth

Rodam via `crontab`:

```
* * * * *  DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/dev/dotfiles/scripts/wallpaper/change_wallpapers.sh
* * * * *  DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/dev/dotfiles/scripts/check_idle >> ~/dev/dotfiles/logs/check_idle.log 2>&1
*/2 * * * * DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/dev/dotfiles/scripts/hibernate_if_idle >> ~/dev/dotfiles/logs/hibernate_if_idle.log 2>&1
* * * * * DISPLAY=:0 XAUTHORITY=$HOME/.Xauthority ~/dev/dotfiles/scripts/check_bluetooth_device_info
```