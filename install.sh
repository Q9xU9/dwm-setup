#!/bin/bash
# install-sway.sh — Полноценное Sway окружение на CachyOS/Arch
# Версия 1.0 — Производительность + Практичность + Стиль
# 6 тем на выбор (включая монохромную), Waybar, всё для комфорта

set -e

export GIT_TERMINAL_PROMPT=0

# ===================== ЦВЕТА ЛОГА =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}[i]${NC} $1"; }
title() { echo -e "\n${BOLD}${CYAN}▶ $1${NC}\n"; }

# ===================== 1. ПАКЕТЫ =====================
install_packages() {
    title "Установка базовых пакетов Sway + Wayland"
    sudo pacman -Syu --noconfirm || warn "Не удалось обновить БД"

    sudo pacman -S --needed --noconfirm \
        sway swaybg swayidle swaylock \
        waybar wofi \
        xorg-xwayland \
        wl-clipboard cliphist \
        grim slurp swappy \
        wlsunset \
        brightnessctl playerctl \
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
        alacritty foot \
        thunar thunar-volman thunar-archive-plugin \
        file-roller unzip p7zip \
        polkit-gnome \
        network-manager-applet networkmanager \
        blueman bluez bluez-utils \
        libnotify mako \
        xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
        xdg-user-dirs xdg-utils \
        qt5-wayland qt6-wayland \
        gnome-themes-extra adwaita-icon-theme papirus-icon-theme \
        gsettings-desktop-schemas dconf \
        noto-fonts noto-fonts-cjk noto-fonts-emoji \
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
        ttf-font-awesome \
        htop btop neofetch \
        curl wget git \
        bc jq socat \
        imv mpv \
        zathura zathura-pdf-mupdf \
        firefox
        
    log "Базовые пакеты установлены"
}

# ===================== 2. YAY =====================
install_yay() {
    title "Установка yay"
    if ! command -v yay &>/dev/null; then
        if sudo pacman -S --needed --noconfirm yay 2>/dev/null; then
            log "yay установлен через pacman"
        else
            cd /tmp
            rm -rf yay-bin
            git clone --depth 1 https://aur.archlinux.org/yay-bin.git
            cd yay-bin
            makepkg -si --noconfirm
            cd ~
        fi
    else
        log "yay уже установлен"
    fi
}

# ===================== 3. AUR ПАКЕТЫ =====================
install_aur_packages() {
    title "Установка AUR пакетов"

    info "swaylock-effects (красивая блокировка)..."
    yay -S --needed --noconfirm swaylock-effects 2>/dev/null || warn "Не установлен"

    info "wlogout (меню выхода)..."
    yay -S --needed --noconfirm wlogout 2>/dev/null || warn "Не установлен"

    info "Zen Browser..."
    yay -S --needed --noconfirm zen-browser-bin 2>/dev/null || warn "Установите вручную"

    info "Telegram..."
    sudo pacman -S --needed --noconfirm telegram-desktop 2>/dev/null || \
        yay -S --needed --noconfirm telegram-desktop

    info "Steam..."
    sudo pacman -S --needed --noconfirm steam 2>/dev/null || warn "Steam не установлен"

    info "Proton..."
    yay -S --needed --noconfirm proton-cachyos-bin 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Установите Proton через Steam"

    info "wl-clip-persist (буфер сохраняется после закрытия окна)..."
    yay -S --needed --noconfirm wl-clip-persist 2>/dev/null || warn "Не установлен"
}

# ===================== 4. СТРУКТУРА ПАПОК =====================
create_dirs() {
    title "Создание структуры директорий"
    mkdir -p ~/.config/sway/{config.d,themes,scripts}
    mkdir -p ~/.config/waybar/themes
    mkdir -p ~/.config/wofi
    mkdir -p ~/.config/mako
    mkdir -p ~/.config/swaylock
    mkdir -p ~/.config/wlogout
    mkdir -p ~/.config/alacritty
    mkdir -p ~/bin
    mkdir -p ~/Pictures/Screenshots
    mkdir -p ~/Pictures/Wallpapers
    xdg-user-dirs-update 2>/dev/null || true
    log "Директории созданы"
}

# ===================== 5. ТЕМЫ (ЦВЕТОВЫЕ СХЕМЫ) =====================
create_themes() {
    title "Создание файлов тем"

    # ─── ТЕМА 1: MONOCHROME (чёрно-белая, ваша любимая) ───
    cat > ~/.config/sway/themes/monochrome.conf << 'EOF'
# Monochrome — минимализм, чёрно-белая
set $bg          #0c0b0a
set $bg_alt      #1c1a18
set $fg          #b5ada6
set $fg_bright   #f5efe6
set $accent      #f5efe6
set $urgent      #8a8177
set $border      #3a3632
EOF

    # ─── ТЕМА 2: CATPPUCCIN MOCHA (самая популярная в 2024) ───
    cat > ~/.config/sway/themes/catppuccin.conf << 'EOF'
# Catppuccin Mocha — популярная пастельная тёмная
set $bg          #1e1e2e
set $bg_alt      #313244
set $fg          #cdd6f4
set $fg_bright   #f5e0dc
set $accent      #cba6f7
set $urgent      #f38ba8
set $border      #45475a
EOF

    # ─── ТЕМА 3: TOKYO NIGHT (популярная у разработчиков) ───
    cat > ~/.config/sway/themes/tokyonight.conf << 'EOF'
# Tokyo Night — сине-фиолетовая киберпанк
set $bg          #1a1b26
set $bg_alt      #24283b
set $fg          #a9b1d6
set $fg_bright   #c0caf5
set $accent      #7aa2f7
set $urgent      #f7768e
set $border      #414868
EOF

    # ─── ТЕМА 4: GRUVBOX DARK (тёплая, ретро) ───
    cat > ~/.config/sway/themes/gruvbox.conf << 'EOF'
# Gruvbox Dark — тёплая ретро
set $bg          #282828
set $bg_alt      #3c3836
set $fg          #ebdbb2
set $fg_bright   #fbf1c7
set $accent      #d79921
set $urgent      #cc241d
set $border      #504945
EOF

    # ─── ТЕМА 5: NORD (спокойная синяя) ───
    cat > ~/.config/sway/themes/nord.conf << 'EOF'
# Nord — арктическая, приглушённая
set $bg          #2e3440
set $bg_alt      #3b4252
set $fg          #d8dee9
set $fg_bright   #eceff4
set $accent      #88c0d0
set $urgent      #bf616a
set $border      #4c566a
EOF

    # ─── ТЕМА 6: DRACULA (яркая, контрастная) ───
    cat > ~/.config/sway/themes/dracula.conf << 'EOF'
# Dracula — контрастная фиолетовая
set $bg          #282a36
set $bg_alt      #44475a
set $fg          #f8f8f2
set $fg_bright   #ffffff
set $accent      #bd93f9
set $urgent      #ff5555
set $border      #6272a4
EOF

    # Активная тема — по умолчанию монохром
    ln -sf ~/.config/sway/themes/monochrome.conf ~/.config/sway/themes/current.conf
    log "6 тем созданы. Активна: monochrome"
}

# ===================== 6. ПЕРЕКЛЮЧАТЕЛЬ ТЕМ =====================
create_theme_switcher() {
    title "Создание переключателя тем"

    cat > ~/bin/theme-switcher << 'THEMESW'
#!/bin/bash
# Переключатель тем Sway + Waybar + Alacritty + Mako

THEMES_DIR="$HOME/.config/sway/themes"
WAYBAR_THEMES="$HOME/.config/waybar/themes"

CHOICE=$(echo -e "monochrome\ncatppuccin\ntokyonight\ngruvbox\nnord\ndracula" | \
    wofi --dmenu --prompt "Выбор темы:" --width 300 --height 300)

[ -z "$CHOICE" ] && exit 0

# Sway
ln -sf "$THEMES_DIR/${CHOICE}.conf" "$THEMES_DIR/current.conf"

# Waybar
ln -sf "$WAYBAR_THEMES/${CHOICE}.css" "$HOME/.config/waybar/style.css"

# Alacritty
ln -sf "$HOME/.config/alacritty/themes/${CHOICE}.toml" "$HOME/.config/alacritty/current-theme.toml"

# Mako
ln -sf "$HOME/.config/mako/themes/${CHOICE}" "$HOME/.config/mako/config"

# Перезапуск компонентов
swaymsg reload
pkill waybar && waybar &
pkill mako && mako &

notify-send "Тема изменена" "Применена: $CHOICE" -i preferences-desktop-theme
THEMESW
    chmod +x ~/bin/theme-switcher
    log "Переключатель тем создан (Super+Shift+T)"
}

# ===================== 7. КОНФИГ SWAY =====================
create_sway_config() {
    title "Создание конфигурации Sway"

    cat > ~/.config/sway/config << 'SWAYCFG'
### Sway Config — Performance + Practicality Edition ###

# ─── МОДИФИКАТОР ───
set $mod Mod4

# ─── ПРОГРАММЫ ПО УМОЛЧАНИЮ ───
set $term alacritty
set $menu wofi --show drun
set $filemanager thunar
set $browser zen-browser
set $editor alacritty -e nvim

# ─── ЗАГРУЗКА ТЕМЫ ───
include ~/.config/sway/themes/current.conf

# ─── ВНЕШНИЙ ВИД ───
font pango:JetBrains Mono 10

# Границы
default_border pixel 2
default_floating_border pixel 2
smart_borders on
smart_gaps on
gaps inner 8
gaps outer 4

# Цвета (используются переменные из темы)
# class                 border      backgr.     text        indicator   child_border
client.focused          $accent     $bg_alt     $fg_bright  $accent     $accent
client.focused_inactive $border     $bg         $fg         $border     $border
client.unfocused        $border     $bg         $fg         $border     $border
client.urgent           $urgent     $urgent     $fg_bright  $urgent     $urgent
client.background       $bg

# ─── ОБОИ ───
output * bg #0c0b0a solid_color
# Если есть обои: output * bg ~/Pictures/wallpaper.png fill

# ─── ВВОД (МЫШЬ, КЛАВИАТУРА) ───
input "type:keyboard" {
    xkb_layout us,ru
    xkb_options grp:win_space_toggle,caps:escape
    repeat_delay 250
    repeat_rate 40
}

input "type:pointer" {
    accel_profile flat
    pointer_accel 0
}

input "type:touchpad" {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
}

# ─── ПРОИЗВОДИТЕЛЬНОСТЬ ───
# VRR / Adaptive Sync — критично для игр
output * adaptive_sync on

# Отключить эффекты для полноэкранных окон (максимум FPS)
for_window [app_id=".*"] inhibit_idle fullscreen

# ─── ПРАВИЛА ОКОН ───
for_window [app_id="pavucontrol"] floating enable, resize set 800 600
for_window [app_id="blueman-manager"] floating enable
for_window [app_id="nm-connection-editor"] floating enable
for_window [app_id="thunar" title="File Operation Progress"] floating enable
for_window [title="Picture-in-Picture"] floating enable, sticky enable
for_window [app_id="firefox" title="^Picture-in-Picture$"] floating enable, sticky enable
for_window [class="steam" title="^Friends List$"] floating enable
for_window [class="Steam" title="^Friends List$"] floating enable

# Steam — на 4-й рабочий стол
assign [class="steam"] workspace 4
assign [class="Steam"] workspace 4

# Telegram — на 3-й
assign [app_id="org.telegram.desktop"] workspace 3

# ─── ЗАПУСК ПРОГРАММ ───
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+w exec $browser
bindsym $mod+e exec $filemanager
bindsym $mod+t exec telegram-desktop
bindsym $mod+Shift+s exec steam

# ─── УПРАВЛЕНИЕ ОКНАМИ ───
bindsym $mod+Shift+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec ~/bin/power-menu

# Фокус
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# Перемещение
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Разделение
bindsym $mod+b splith
bindsym $mod+v splitv

# Раскладки
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+g layout toggle split

# Полный экран / плавающий
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Скрыть панель
bindsym $mod+y exec pkill -SIGUSR1 waybar

# ─── РАБОЧИЕ СТОЛЫ ───
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9

bindsym $mod+Tab workspace back_and_forth

# ─── СКРИНШОТЫ ───
bindsym Print exec ~/bin/screenshot area
bindsym Shift+Print exec ~/bin/screenshot full
bindsym Ctrl+Print exec ~/bin/screenshot window
bindsym $mod+Print exec ~/bin/screenshot edit

# ─── БУФЕР ОБМЕНА ───
bindsym $mod+shift+v exec cliphist list | wofi --dmenu | cliphist decode | wl-copy

# ─── БЛОКИРОВКА / ВЫХОД ───
bindsym $mod+Shift+l exec ~/bin/lockscreen

# ─── ПЕРЕКЛЮЧАТЕЛЬ ТЕМ ───
bindsym $mod+Shift+t exec ~/bin/theme-switcher

# ─── МУЛЬТИМЕДИА ───
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86AudioMicMute exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

# ─── РЕЖИМ ИЗМЕНЕНИЯ РАЗМЕРА ───
mode "resize" {
    bindsym h resize shrink width 20px
    bindsym j resize grow height 20px
    bindsym k resize shrink height 20px
    bindsym l resize grow width 20px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# ─── УПРАВЛЕНИЕ УВЕДОМЛЕНИЯМИ ───
bindsym $mod+n exec makoctl dismiss
bindsym $mod+Shift+n exec makoctl dismiss --all
bindsym $mod+grave exec makoctl restore

# ─── АВТОЗАПУСК ───
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec waybar
exec mako
exec wl-paste --type text --watch cliphist store
exec wl-paste --type image --watch cliphist store
exec wl-clip-persist --clipboard regular
exec nm-applet --indicator
exec blueman-applet
exec wlsunset -l 55.7 -L 37.6 -t 3500 -T 6500
exec swayidle -w \
    timeout 300 '~/bin/lockscreen' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep '~/bin/lockscreen'

# ─── ПОДКЛЮЧАЕМЫЕ КОНФИГИ ───
include ~/.config/sway/config.d/*.conf
SWAYCFG

    log "Sway config создан"
}

# ===================== 8. WAYBAR =====================
create_waybar() {
    title "Создание Waybar"

    # ─── КОНФИГ WAYBAR ───
    cat > ~/.config/waybar/config.jsonc << 'WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["sway/workspaces", "sway/mode", "sway/window"],
    "modules-center": ["clock"],
    "modules-right": [
        "tray",
        "idle_inhibitor",
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "temperature",
        "backlight",
        "battery",
        "custom/notifications"
    ],

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },

    "sway/mode": {
        "format": "<span style=\"italic\">{}</span>"
    },

    "sway/window": {
        "max-length": 50,
        "tooltip": false
    },

    "clock": {
        "format": "{:%H:%M   %a, %d %b}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "calendar": {
            "mode": "month",
            "mode-mon-col": 3,
            "on-scroll": 1
        }
    },

    "cpu": {
        "format": "CPU {usage}%",
        "interval": 5,
        "tooltip": true
    },

    "memory": {
        "format": "RAM {percentage}%",
        "interval": 5,
        "tooltip-format": "{used:0.1f}G / {total:0.1f}G"
    },

    "temperature": {
        "critical-threshold": 80,
        "format": "{temperatureC}°C",
        "interval": 5
    },

    "backlight": {
        "format": "BR {percent}%",
        "on-scroll-up": "brightnessctl set +5%",
        "on-scroll-down": "brightnessctl set 5%-"
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": "CHR {capacity}%",
        "format-plugged": "AC {capacity}%",
        "format-icons": ["BAT", "BAT", "BAT", "BAT", "BAT"]
    },

    "network": {
        "format-wifi": "WIFI {signalStrength}%",
        "format-ethernet": "ETH",
        "format-disconnected": "OFF",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "nm-connection-editor"
    },

    "pulseaudio": {
        "format": "VOL {volume}%",
        "format-muted": "MUTE",
        "format-bluetooth": "BT {volume}%",
        "on-click": "pavucontrol",
        "scroll-step": 5
    },

    "tray": {
        "icon-size": 16,
        "spacing": 8
    },

    "idle_inhibitor": {
        "format": "{icon}",
        "format-icons": {
            "activated": "AWAKE",
            "deactivated": "IDLE"
        }
    },

    "custom/notifications": {
        "format": "N",
        "on-click": "makoctl restore",
        "on-click-right": "makoctl dismiss --all",
        "tooltip": false
    }
}
WAYBAR

    # ─── ТЕМЫ WAYBAR ───

    # Monochrome
    cat > ~/.config/waybar/themes/monochrome.css << 'EOF'
* {
    font-family: "JetBrains Mono", "Font Awesome 6 Free";
    font-size: 12px;
    border: none;
    border-radius: 0;
    min-height: 0;
}
window#waybar {
    background: #0c0b0a;
    color: #b5ada6;
    border-bottom: 1px solid #1c1a18;
}
#workspaces button {
    padding: 0 8px;
    color: #b5ada6;
    background: transparent;
    border-bottom: 2px solid transparent;
}
#workspaces button.focused {
    color: #f5efe6;
    border-bottom: 2px solid #f5efe6;
}
#workspaces button.urgent { color: #8a8177; }
#clock, #battery, #cpu, #memory, #temperature, #backlight,
#network, #pulseaudio, #tray, #mode, #idle_inhibitor,
#custom-notifications, #window {
    padding: 0 10px;
    color: #b5ada6;
}
#clock { color: #f5efe6; font-weight: bold; }
#battery.warning { color: #d5cdc4; }
#battery.critical { color: #f5efe6; }
EOF

    # Catppuccin
    cat > ~/.config/waybar/themes/catppuccin.css << 'EOF'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #1e1e2e; color: #cdd6f4; }
#workspaces button { padding: 0 8px; color: #6c7086; background: transparent; }
#workspaces button.focused { color: #cba6f7; border-bottom: 2px solid #cba6f7; }
#workspaces button.urgent { color: #f38ba8; }
#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-notifications, #window { padding: 0 10px; color: #cdd6f4; }
#clock { color: #f5e0dc; font-weight: bold; }
#battery.warning { color: #fab387; }
#battery.critical { color: #f38ba8; }
EOF

    # Tokyo Night
    cat > ~/.config/waybar/themes/tokyonight.css << 'EOF'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #1a1b26; color: #a9b1d6; }
#workspaces button { padding: 0 8px; color: #565f89; background: transparent; }
#workspaces button.focused { color: #7aa2f7; border-bottom: 2px solid #7aa2f7; }
#workspaces button.urgent { color: #f7768e; }
#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-notifications, #window { padding: 0 10px; color: #a9b1d6; }
#clock { color: #c0caf5; font-weight: bold; }
#battery.warning { color: #e0af68; }
#battery.critical { color: #f7768e; }
EOF

    # Gruvbox
    cat > ~/.config/waybar/themes/gruvbox.css << 'EOF'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #282828; color: #ebdbb2; }
#workspaces button { padding: 0 8px; color: #928374; background: transparent; }
#workspaces button.focused { color: #d79921; border-bottom: 2px solid #d79921; }
#workspaces button.urgent { color: #cc241d; }
#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-notifications, #window { padding: 0 10px; color: #ebdbb2; }
#clock { color: #fbf1c7; font-weight: bold; }
#battery.warning { color: #d79921; }
#battery.critical { color: #cc241d; }
EOF

    # Nord
    cat > ~/.config/waybar/themes/nord.css << 'EOF'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #2e3440; color: #d8dee9; }
#workspaces button { padding: 0 8px; color: #4c566a; background: transparent; }
#workspaces button.focused { color: #88c0d0; border-bottom: 2px solid #88c0d0; }
#workspaces button.urgent { color: #bf616a; }
#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-notifications, #window { padding: 0 10px; color: #d8dee9; }
#clock { color: #eceff4; font-weight: bold; }
#battery.warning { color: #ebcb8b; }
#battery.critical { color: #bf616a; }
EOF

    # Dracula
    cat > ~/.config/waybar/themes/dracula.css << 'EOF'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free"; font-size: 12px; border: none; border-radius: 0; min-height: 0; }
window#waybar { background: #282a36; color: #f8f8f2; }
#workspaces button { padding: 0 8px; color: #6272a4; background: transparent; }
#workspaces button.focused { color: #bd93f9; border-bottom: 2px solid #bd93f9; }
#workspaces button.urgent { color: #ff5555; }
#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-notifications, #window { padding: 0 10px; color: #f8f8f2; }
#clock { color: #ffffff; font-weight: bold; }
#battery.warning { color: #f1fa8c; }
#battery.critical { color: #ff5555; }
EOF

    # Активная — монохром
    ln -sf ~/.config/waybar/themes/monochrome.css ~/.config/waybar/style.css
    log "Waybar настроен с 6 темами"
}

# ===================== 9. ALACRITTY (с темами) =====================
create_alacritty() {
    title "Создание Alacritty"

    mkdir -p ~/.config/alacritty/themes

    # Базовый конфиг
    cat > ~/.config/alacritty/alacritty.toml << 'EOF'
[general]
import = ["~/.config/alacritty/current-theme.toml"]

[env]
TERM = "xterm-256color"

[window]
padding = { x = 12, y = 12 }
dynamic_padding = true
decorations = "None"
opacity = 0.95

[scrolling]
history = 10000
multiplier = 3

[font]
size = 12.0
[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"
[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"
[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

[keyboard]
bindings = [
    { key = "V", mods = "Control|Shift", action = "Paste" },
    { key = "C", mods = "Control|Shift", action = "Copy" },
    { key = "Plus", mods = "Control", action = "IncreaseFontSize" },
    { key = "Minus", mods = "Control", action = "DecreaseFontSize" },
    { key = "Key0", mods = "Control", action = "ResetFontSize" }
]

[mouse]
hide_when_typing = true
EOF

    # Темы для Alacritty
    cat > ~/.config/alacritty/themes/monochrome.toml << 'EOF'
[colors.primary]
background = "#0c0b0a"
foreground = "#b5ada6"
[colors.cursor]
text = "#0c0b0a"
cursor = "#f5efe6"
[colors.normal]
black = "#0c0b0a"; red = "#8a8177"; green = "#6a635a"; yellow = "#d5cdc4"
blue = "#5a544d"; magenta = "#9a9086"; cyan = "#4a453f"; white = "#b5ada6"
[colors.bright]
black = "#3a3632"; red = "#a89e93"; green = "#8a8177"; yellow = "#f5efe6"
blue = "#7a7268"; magenta = "#c5bdb2"; cyan = "#6a635a"; white = "#f5efe6"
EOF

    cat > ~/.config/alacritty/themes/catppuccin.toml << 'EOF'
[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"
[colors.cursor]
text = "#1e1e2e"; cursor = "#f5e0dc"
[colors.normal]
black = "#45475a"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af"
blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#bac2de"
[colors.bright]
black = "#585b70"; red = "#f38ba8"; green = "#a6e3a1"; yellow = "#f9e2af"
blue = "#89b4fa"; magenta = "#f5c2e7"; cyan = "#94e2d5"; white = "#a6adc8"
EOF

    cat > ~/.config/alacritty/themes/tokyonight.toml << 'EOF'
[colors.primary]
background = "#1a1b26"
foreground = "#a9b1d6"
[colors.normal]
black = "#32344a"; red = "#f7768e"; green = "#9ece6a"; yellow = "#e0af68"
blue = "#7aa2f7"; magenta = "#ad8ee6"; cyan = "#449dab"; white = "#787c99"
[colors.bright]
black = "#444b6a"; red = "#ff7a93"; green = "#b9f27c"; yellow = "#ff9e64"
blue = "#7da6ff"; magenta = "#bb9af7"; cyan = "#0db9d7"; white = "#acb0d0"
EOF

    cat > ~/.config/alacritty/themes/gruvbox.toml << 'EOF'
[colors.primary]
background = "#282828"
foreground = "#ebdbb2"
[colors.normal]
black = "#282828"; red = "#cc241d"; green = "#98971a"; yellow = "#d79921"
blue = "#458588"; magenta = "#b16286"; cyan = "#689d6a"; white = "#a89984"
[colors.bright]
black = "#928374"; red = "#fb4934"; green = "#b8bb26"; yellow = "#fabd2f"
blue = "#83a598"; magenta = "#d3869b"; cyan = "#8ec07c"; white = "#ebdbb2"
EOF

    cat > ~/.config/alacritty/themes/nord.toml << 'EOF'
[colors.primary]
background = "#2e3440"
foreground = "#d8dee9"
[colors.normal]
black = "#3b4252"; red = "#bf616a"; green = "#a3be8c"; yellow = "#ebcb8b"
blue = "#81a1c1"; magenta = "#b48ead"; cyan = "#88c0d0"; white = "#e5e9f0"
[colors.bright]
black = "#4c566a"; red = "#bf616a"; green = "#a3be8c"; yellow = "#ebcb8b"
blue = "#81a1c1"; magenta = "#b48ead"; cyan = "#8fbcbb"; white = "#eceff4"
EOF

    cat > ~/.config/alacritty/themes/dracula.toml << 'EOF'
[colors.primary]
background = "#282a36"
foreground = "#f8f8f2"
[colors.normal]
black = "#21222c"; red = "#ff5555"; green = "#50fa7b"; yellow = "#f1fa8c"
blue = "#bd93f9"; magenta = "#ff79c6"; cyan = "#8be9fd"; white = "#f8f8f2"
[colors.bright]
black = "#6272a4"; red = "#ff6e6e"; green = "#69ff94"; yellow = "#ffffa5"
blue = "#d6acff"; magenta = "#ff92df"; cyan = "#a4ffff"; white = "#ffffff"
EOF

    ln -sf ~/.config/alacritty/themes/monochrome.toml ~/.config/alacritty/current-theme.toml
    log "Alacritty настроен с 6 темами"
}

# ===================== 10. WOFI =====================
create_wofi() {
    title "Создание Wofi (launcher)"

    cat > ~/.config/wofi/config << 'EOF'
width=600
height=400
location=center
show=drun
prompt=Поиск:
filter_rate=100
allow_markup=true
no_actions=true
halign=fill
orientation=vertical
content_halign=fill
insensitive=true
allow_images=true
image_size=24
gtk_dark=true
EOF

    cat > ~/.config/wofi/style.css << 'EOF'
window {
    margin: 0px;
    background-color: #0c0b0a;
    border: 2px solid #3a3632;
    font-family: "JetBrains Mono";
    font-size: 12px;
}
#input {
    margin: 8px;
    padding: 8px;
    border: none;
    color: #f5efe6;
    background-color: #1c1a18;
    border-radius: 0;
}
#inner-box { margin: 4px; background-color: #0c0b0a; }
#outer-box { margin: 0; padding: 4px; background-color: #0c0b0a; }
#scroll { margin: 0; padding: 0; }
#text { margin: 4px; color: #b5ada6; }
#entry { padding: 6px; }
#entry:selected {
    background-color: #1c1a18;
    border-left: 2px solid #f5efe6;
}
#entry:selected #text { color: #f5efe6; }
EOF
    log "Wofi настроен"
}

# ===================== 11. MAKO (уведомления) =====================
create_mako() {
    title "Создание Mako"

    mkdir -p ~/.config/mako/themes

    cat > ~/.config/mako/themes/monochrome << 'EOF'
font=JetBrains Mono 10
background-color=#0c0b0a
text-color=#b5ada6
border-color=#3a3632
border-size=2
border-radius=0
width=350
height=100
margin=10
padding=12
default-timeout=5000
ignore-timeout=1
max-icon-size=48
icon-location=left

[urgency=low]
border-color=#3a3632
default-timeout=3000

[urgency=normal]
border-color=#5a544d

[urgency=critical]
border-color=#f5efe6
text-color=#f5efe6
default-timeout=0
EOF

    # Другие темы (сокращенно, с теми же настройками, только цвета)
    for theme in catppuccin tokyonight gruvbox nord dracula; do
        cp ~/.config/mako/themes/monochrome ~/.config/mako/themes/$theme
    done
    
    ln -sf ~/.config/mako/themes/monochrome ~/.config/mako/config
    log "Mako настроен"
}

# ===================== 12. SWAYLOCK =====================
create_swaylock() {
    title "Настройка блокировки экрана"

    cat > ~/.config/swaylock/config << 'EOF'
daemonize
show-failed-attempts
clock
screenshots
effect-blur=15x3
effect-vignette=0.5:0.5
color=0c0b0a
font=JetBrains Mono
indicator
indicator-radius=120
indicator-thickness=8
line-color=00000000
ring-color=3a3632
inside-color=00000000
key-hl-color=f5efe6
separator-color=00000000
text-color=f5efe6
text-caps-lock-color=""
line-ver-color=f5efe6
ring-ver-color=b5ada6
inside-ver-color=00000000
text-ver-color=f5efe6
ring-wrong-color=8a8177
text-wrong-color=f5efe6
inside-wrong-color=00000000
inside-clear-color=00000000
text-clear-color=f5efe6
ring-clear-color=b5ada6
line-clear-color=00000000
line-wrong-color=00000000
bs-hl-color=f5efe6
grace=2
grace-no-mouse
grace-no-touch
datestr=%a, %d %b
timestr=%H:%M
fade-in=0.2
EOF

    cat > ~/bin/lockscreen << 'EOF'
#!/bin/bash
if command -v swaylock &>/dev/null; then
    if swaylock --help 2>&1 | grep -q "effect-blur"; then
        swaylock
    else
        swaylock -c 0c0b0a
    fi
fi
EOF
    chmod +x ~/bin/lockscreen
    log "Swaylock настроен"
}

# ===================== 13. СКРИНШОТЫ =====================
create_screenshots() {
    title "Создание скриптов скриншотов"

    cat > ~/bin/screenshot << 'EOF'
#!/bin/bash
# Универсальный скриншот-тул для Wayland

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$1" in
    area)
        grim -g "$(slurp)" "$FILE"
        ;;
    full)
        grim "$FILE"
        ;;
    window)
        grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" "$FILE"
        ;;
    edit)
        grim -g "$(slurp)" - | swappy -f - -o "$FILE"
        ;;
    *)
        echo "Использование: $0 {area|full|window|edit}"
        exit 1
        ;;
esac

if [ -f "$FILE" ]; then
    wl-copy < "$FILE"
    notify-send "Скриншот" "Сохранён: $(basename $FILE)" -i "$FILE" -t 3000
fi
EOF
    chmod +x ~/bin/screenshot
    log "Скрипт скриншотов создан (area/full/window/edit)"
}

# ===================== 14. POWER MENU =====================
create_power_menu() {
    title "Создание меню питания"

    cat > ~/bin/power-menu << 'EOF'
#!/bin/bash
# Меню питания через wofi

CHOICE=$(echo -e "Заблокировать\nВыйти\nПерезагрузить\nВыключить\nЖдущий режим" | \
    wofi --dmenu --prompt "Питание:" --width 300 --height 250)

case "$CHOICE" in
    "Заблокировать") ~/bin/lockscreen ;;
    "Выйти") swaymsg exit ;;
    "Перезагрузить") systemctl reboot ;;
    "Выключить") systemctl poweroff ;;
    "Ждущий режим") systemctl suspend && ~/bin/lockscreen ;;
esac
EOF
    chmod +x ~/bin/power-menu
    log "Power menu создан (Super+Shift+E)"
}

# ===================== 15. ОПТИМИЗАЦИЯ СИСТЕМЫ =====================
optimize_system() {
    title "Системные оптимизации"

    # Wayland переменные окружения
    mkdir -p ~/.config/environment.d
    cat > ~/.config/environment.d/10-wayland.conf << 'EOF'
# Wayland everywhere
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
SDL_VIDEODRIVER=wayland
_JAVA_AWT_WM_NONREPARENTING=1
CLUTTER_BACKEND=wayland
GDK_BACKEND=wayland,x11
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_DESKTOP=sway

# Темы
GTK_THEME=Adwaita-dark
EOF

    # GTK темы
    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrains Mono 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF

    mkdir -p ~/.config/gtk-4.0
    cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini

    # Включить сервисы
    sudo systemctl enable NetworkManager 2>/dev/null || true
    sudo systemctl enable bluetooth 2>/dev/null || true
    systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

    log "Оптимизации применены"
}

# ===================== 16. ШПАРГАЛКА =====================
create_cheatsheet() {
    cat > ~/sway-keybinds.txt << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              SWAY KEYBINDINGS — ШПАРГАЛКА                    ║
╠══════════════════════════════════════════════════════════════╣
║ ПРОГРАММЫ                                                    ║
║   Super + Enter        Терминал (Alacritty)                  ║
║   Super + D            Меню приложений (Wofi)                ║
║   Super + W            Zen Browser                           ║
║   Super + E            Файловый менеджер (Thunar)            ║
║   Super + T            Telegram                              ║
║   Super + Shift + S    Steam                                 ║
║   Super + Space        Переключить раскладку US/RU           ║
║                                                              ║
║ ОКНА                                                         ║
║   Super + H/J/K/L      Фокус влево/вниз/вверх/вправо         ║
║   Super + Shift + HJKL Переместить окно                      ║
║   Super + F            Полный экран                          ║
║   Super + Shift+Space  Плавающее окно                        ║
║   Super + Shift + Q    Закрыть окно                          ║
║   Super + R            Режим resize (потом HJKL)             ║
║   Super + B / V        Разделение горизонт./вертик.          ║
║   Super + S / W / G    Stack / Tab / Toggle split            ║
║                                                              ║
║ РАБОЧИЕ СТОЛЫ                                                ║
║   Super + 1..9         Перейти на стол                       ║
║   Super + Shift + 1..9 Перенести окно                        ║
║   Super + Tab          Предыдущий стол                       ║
║                                                              ║
║ СКРИНШОТЫ                                                    ║
║   Print                Область → буфер + файл                ║
║   Shift + Print        Весь экран                            ║
║   Ctrl + Print         Активное окно                         ║
║   Super + Print        Область + редактор (Swappy)           ║
║                                                              ║
║ БУФЕР / УВЕДОМЛЕНИЯ                                          ║
║   Super + Shift + V    История буфера (cliphist)             ║
║   Super + N            Скрыть текущее уведомление            ║
║   Super + Shift + N    Скрыть ВСЕ уведомления                ║
║   Super + `            Восстановить последнее уведомление    ║
║                                                              ║
║ СИСТЕМА                                                      ║
║   Super + Shift + L    Заблокировать                         ║
║   Super + Shift + E    Меню питания                          ║
║   Super + Shift + T    Переключатель тем                     ║
║   Super + Shift + C    Перезагрузить Sway                    ║
║   Super + Y            Скрыть/показать Waybar                ║
║                                                              ║
║ ТЕМЫ ДОСТУПНЫ                                                ║
║   monochrome | catppuccin | tokyonight |                     ║
║   gruvbox | nord | dracula                                   ║
╚══════════════════════════════════════════════════════════════╝
EOF
    log "Шпаргалка сохранена в ~/sway-keybinds.txt"
}

# ===================== 17. ДИАГНОСТИКА =====================
run_diagnostics() {
    title "Диагностика"
    
    command -v sway &>/dev/null && log "✓ Sway" || err "✗ Sway не найден"
    command -v waybar &>/dev/null && log "✓ Waybar" || warn "✗ Waybar"
    command -v wofi &>/dev/null && log "✓ Wofi" || warn "✗ Wofi"
    command -v mako &>/dev/null && log "✓ Mako" || warn "✗ Mako"
    command -v grim &>/dev/null && log "✓ Grim" || warn "✗ Grim"
    command -v slurp &>/dev/null && log "✓ Slurp" || warn "✗ Slurp"
    command -v swaylock &>/dev/null && log "✓ Swaylock" || warn "✗ Swaylock"
    command -v cliphist &>/dev/null && log "✓ Cliphist" || warn "✗ Cliphist"
    [ -x ~/bin/theme-switcher ] && log "✓ Переключатель тем" || warn "✗ Переключатель тем"
    [ -x ~/bin/power-menu ] && log "✓ Power menu" || warn "✗ Power menu"
    [ -x ~/bin/screenshot ] && log "✓ Screenshot tool" || warn "✗ Screenshot"
}

# ===================== MAIN =====================
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   SWAY — Performance Edition v1.0            ║"
    echo "║   6 тем + Waybar + Максимум удобства         ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    install_packages
    install_yay
    install_aur_packages
    create_dirs
    create_themes
    create_theme_switcher
    create_sway_config
    create_waybar
    create_alacritty
    create_wofi
    create_mako
    create_swaylock
    create_screenshots
    create_power_menu
    optimize_system
    create_cheatsheet
    run_diagnostics

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Что дальше:"
    echo "  1. Выйдите из системы"
    echo "  2. В экране входа выберите сессию 'Sway'"
    echo "  3. Войдите — Sway запустится с монохромной темой"
    echo ""
    info "Смена темы: Super + Shift + T"
    info "Шпаргалка: cat ~/sway-keybinds.txt"
    echo ""
    warn "Обои: положите картинку в ~/Pictures/wallpaper.png"
    warn "    и раскомментируйте строку 'output * bg' в ~/.config/sway/config"
    echo ""
}

main "$@"
