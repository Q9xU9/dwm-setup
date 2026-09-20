#!/usr/bin/env bash
# ============================================================
#  CachyOS Sway Setup Script
#  - Тёплая ч/б тема (warm monochrome)
#  - CapsLock = смена языка
#  - Zen Browser, Steam, nwg-look, gnome-disk-utility
# ============================================================

set -euo pipefail

# ─── Цвета вывода ───────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Проверка ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] && error "Не запускай скрипт от root! Запусти как обычный пользователь."

# ─── AUR Helper ─────────────────────────────────────────────
install_aur_helper() {
    if ! command -v paru &>/dev/null; then
        info "Устанавливаю paru..."
        sudo pacman -S --needed --noconfirm base-devel git
        local tmp=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmp/paru"
        (cd "$tmp/paru" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    else
        info "paru уже установлен."
    fi
}

# ─── Пакеты ─────────────────────────────────────────────────
PACMAN_PKGS=(
    # === Ядро Sway ===
    sway
    swayidle
    swaylock
    swaybg
    sway-contrib

    # === Панель и уведомления ===
    waybar
    mako

    # === Терминал ===
    foot

    # === Лаунчер ===
    wmenu

    # === Скриншоты ===
    grim
    slurp

    # === Статус бар ===
    i3status

    # === Звук ===
    libpulse
    pipewire
    pipewire-pulse
    wireplumber

    # === Яркость и медиа ===
    brightnessctl
    playerctl

    # === Привилегии ===
    polkit
    polkit-gnome

    # === XDG порталы ===
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-user-dirs

    # === X11 поддержка ===
    xorg-xwayland

    # === Шрифты ===
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji

    # === Системные утилиты ===
    wl-clipboard
    cliphist
    network-manager-applet
    blueman
    pavucontrol
    imv
    qt5-wayland
    qt6-wayland

    # === Тема GTK ===
    nwg-look          # Управление GTK-темами (аналог lxappearance для Wayland)
    adwaita-icon-theme

    # === Диски (GNOME) ===
    gnome-disk-utility

    # === Steam ===
    steam

    # === Ввод / раскладки ===
    fcitx5
    fcitx5-configtool
    fcitx5-gtk
    fcitx5-qt
)

AUR_PKGS=(
    zen-browser-bin   # Zen Browser
    autotiling        # Автоматическое тайлинг-разбиение
    wlsunset          # Ночной режим / тёплый свет
)

# ─── Установка ──────────────────────────────────────────────
install_packages() {
    info "Обновляю базу пакетов..."
    sudo pacman -Syu --noconfirm

    info "Устанавливаю пакеты из официальных репозиториев..."
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

    install_aur_helper

    info "Устанавливаю AUR пакеты..."
    paru -S --needed --noconfirm "${AUR_PKGS[@]}"
}

# ─── Директории конфигов ─────────────────────────────────────
setup_dirs() {
    mkdir -p \
        ~/.config/sway \
        ~/.config/waybar \
        ~/.config/mako \
        ~/.config/foot \
        ~/.config/swaylock \
        ~/.local/share/wallpapers
}

# ─── ТЁПЛАЯ Ч/Б ПАЛИТРА ─────────────────────────────────────
# Тёплые монохромные оттенки (слегка кремово-коричневатые)
# bg_dark   = почти чёрный с тёплым оттенком
# bg_mid    = тёмно-серый тёплый
# bg_light  = средне-серый тёплый
# fg_dim    = тусклый бежевый
# fg_main   = светлый кремовый
# accent    = тёплый янтарный/золотой
# urgent    = тёплый терракот

# ─── КОНФИГ SWAY ────────────────────────────────────────────
write_sway_config() {
    info "Записываю конфиг Sway..."
    cat > ~/.config/sway/config << 'EOF'
# ╔══════════════════════════════════════════════════════════╗
# ║           SWAY CONFIG — Тёплая ч/б тема                 ║
# ╚══════════════════════════════════════════════════════════╝

# ── Переменные (тёплая монохромная палитра) ──────────────────
set $bg_dark   #1a1814
set $bg_mid    #2c2820
set $bg_light  #3d3830
set $fg_dim    #8a8070
set $fg_main   #e8dcc8
set $accent    #c8a870
set $urgent    #c87050
set $border    #4a4438

# ── Mod ─────────────────────────────────────────────────────
set $mod Mod4

# ── Терминал и лаунчер ──────────────────────────────────────
set $term foot
set $menu wmenu-run

# ── Шрифт ───────────────────────────────────────────────────
font pango:JetBrainsMono Nerd Font 10

# ── Автостарт ───────────────────────────────────────────────
exec --no-startup-id dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec --no-startup-id mako
exec --no-startup-id nm-applet --indicator
exec --no-startup-id autotiling
exec --no-startup-id wl-paste --type text --watch cliphist store
exec --no-startup-id wl-paste --type image --watch cliphist store
exec_always --no-startup-id swaybg -c "#1a1814"

# ── Раскладка клавиатуры (CapsLock = смена языка) ───────────
input "type:keyboard" {
    xkb_layout  us,ru
    xkb_options grp:caps_toggle    # CapsLock переключает раскладку
    repeat_delay 300
    repeat_rate  40
}

# ── Тачпад ──────────────────────────────────────────────────
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
}

# ── Цвета окон ──────────────────────────────────────────────
#                       border   background  text     indicator  child_border
client.focused          $accent  $bg_mid     $fg_main $accent    $accent
client.focused_inactive $border  $bg_dark    $fg_dim  $border    $border
client.unfocused        $bg_mid  $bg_dark    $fg_dim  $bg_mid    $bg_mid
client.urgent           $urgent  $urgent     $fg_main $urgent    $urgent

# ── Оформление ──────────────────────────────────────────────
default_border          pixel 2
default_floating_border pixel 2
gaps inner              8
gaps outer              4
smart_gaps              on
smart_borders           on

# ── Фокус по мыши ───────────────────────────────────────────
focus_follows_mouse no

# ── Рабочие пространства ────────────────────────────────────
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# ── Горячие клавиши — базовые ───────────────────────────────
bindsym $mod+Return       exec $term
bindsym $mod+d            exec $menu
bindsym $mod+Shift+q      kill
bindsym $mod+Shift+r      reload
bindsym $mod+Shift+e      exec swaynag -t warning -m 'Выйти из Sway?' \
    -B 'Да, выйти' 'swaymsg exit'

# ── Скриншоты ───────────────────────────────────────────────
bindsym Print             exec grim ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Print        exec grim -g "$(slurp)" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png
bindsym $mod+Shift+Print  exec grim -g "$(slurp)" - | wl-copy

# ── Блокировка ──────────────────────────────────────────────
bindsym $mod+l            exec swaylock

# ── Буфер обмена ────────────────────────────────────────────
bindsym $mod+v            exec cliphist list | wmenu | cliphist decode | wl-copy

# ── Навигация окнами ────────────────────────────────────────
bindsym $mod+Left         focus left
bindsym $mod+Down         focus down
bindsym $mod+Up           focus up
bindsym $mod+Right        focus right
bindsym $mod+h            focus left
bindsym $mod+j            focus down
bindsym $mod+k            focus up
bindsym $mod+l            focus right

# ── Перемещение окон ────────────────────────────────────────
bindsym $mod+Shift+Left   move left
bindsym $mod+Shift+Down   move down
bindsym $mod+Shift+Up     move up
bindsym $mod+Shift+Right  move right
bindsym $mod+Shift+h      move left
bindsym $mod+Shift+j      move down
bindsym $mod+Shift+k      move up
bindsym $mod+Shift+l      move right

# ── Тайлинг / разметка ──────────────────────────────────────
bindsym $mod+b            splith
bindsym $mod+BackSpace    splitv
bindsym $mod+s            layout stacking
bindsym $mod+w            layout tabbed
bindsym $mod+e            layout toggle split
bindsym $mod+f            fullscreen toggle
bindsym $mod+Shift+space  floating toggle
bindsym $mod+space        focus mode_toggle
bindsym $mod+a            focus parent

# ── Resize mode ─────────────────────────────────────────────
mode "resize" {
    bindsym Left  resize shrink width  10px
    bindsym Down  resize grow   height 10px
    bindsym Up    resize shrink height 10px
    bindsym Right resize grow   width  10px
    bindsym h     resize shrink width  10px
    bindsym j     resize grow   height 10px
    bindsym k     resize shrink height 10px
    bindsym l     resize grow   width  10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# ── Переключение рабочих пространств ────────────────────────
bindsym $mod+1  workspace number $ws1
bindsym $mod+2  workspace number $ws2
bindsym $mod+3  workspace number $ws3
bindsym $mod+4  workspace number $ws4
bindsym $mod+5  workspace number $ws5
bindsym $mod+6  workspace number $ws6
bindsym $mod+7  workspace number $ws7
bindsym $mod+8  workspace number $ws8
bindsym $mod+9  workspace number $ws9
bindsym $mod+0  workspace number $ws10

# ── Перемещение окон на рабочие пространства ────────────────
bindsym $mod+Shift+1  move container to workspace number $ws1
bindsym $mod+Shift+2  move container to workspace number $ws2
bindsym $mod+Shift+3  move container to workspace number $ws3
bindsym $mod+Shift+4  move container to workspace number $ws4
bindsym $mod+Shift+5  move container to workspace number $ws5
bindsym $mod+Shift+6  move container to workspace number $ws6
bindsym $mod+Shift+7  move container to workspace number $ws7
bindsym $mod+Shift+8  move container to workspace number $ws8
bindsym $mod+Shift+9  move container to workspace number $ws9
bindsym $mod+Shift+0  move container to workspace number $ws10

# ── Громкость (PipeWire/PulseAudio) ─────────────────────────
bindsym XF86AudioRaiseVolume  exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume  exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute         exec pactl set-sink-mute   @DEFAULT_SINK@ toggle

# ── Яркость ─────────────────────────────────────────────────
bindsym XF86MonBrightnessUp   exec brightnessctl set +10%
bindsym XF86MonBrightnessDown exec brightnessctl set 10%-

# ── Медиа ───────────────────────────────────────────────────
bindsym XF86AudioPlay  exec playerctl play-pause
bindsym XF86AudioNext  exec playerctl next
bindsym XF86AudioPrev  exec playerctl previous

# ── Плавающие окна по умолчанию ─────────────────────────────
for_window [app_id="pavucontrol"]         floating enable
for_window [app_id="blueman-manager"]     floating enable
for_window [app_id="nm-connection-editor"] floating enable
for_window [app_id="gnome-disks"]         floating enable
for_window [class="Steam"]                floating enable
for_window [app_id="nwg-look"]            floating enable

# ── Waybar ──────────────────────────────────────────────────
bar {
    swaybar_command waybar
}

# ── Swayidle ────────────────────────────────────────────────
exec swayidle -w \
    timeout 300  'swaylock -f' \
    timeout 600  'swaymsg "output * dpms off"' \
    resume       'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f'

include /etc/sway/config.d/*
EOF
}

# ─── КОНФИГ WAYBAR ──────────────────────────────────────────
write_waybar_config() {
    info "Записываю конфиг Waybar..."

    # --- config ---
    cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left":   ["sway/workspaces", "sway/mode", "sway/scratchpad"],
    "modules-center": ["sway/window"],
    "modules-right":  [
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "temperature",
        "battery",
        "clock",
        "tray"
    ],

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "sway/mode":       { "format": " {}" },
    "sway/scratchpad": {
        "format": "{icon} {count}",
        "show-empty": false,
        "format-icons": ["", ""],
        "tooltip": true,
        "tooltip-format": "{app}: {title}"
    },
    "clock": {
        "timezone": "Europe/Moscow",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}",
        "format": " {:%H:%M}"
    },
    "cpu": {
        "format": " {usage}%",
        "tooltip": false
    },
    "memory": {
        "format": " {}%"
    },
    "temperature": {
        "critical-threshold": 80,
        "format": "{icon} {temperatureC}°C",
        "format-icons": ["", "", ""]
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged":  " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi":       " {signalStrength}%",
        "format-ethernet":   " {ipaddr}",
        "tooltip-format":    " {ifname} via {gwaddr}",
        "format-linked":     " {ifname} (No IP)",
        "format-disconnected":"⚠ Disconnected",
        "format-alt":        "{ifname}: {ipaddr}/{cidr}"
    },
    "pulseaudio": {
        "scroll-step": 5,
        "format":         "{icon} {volume}%",
        "format-muted":   " muted",
        "format-icons":   { "default": ["", "", ""] },
        "on-click": "pavucontrol"
    },
    "tray": { "spacing": 10 }
}
EOF

    # --- style.css (тёплая ч/б тема) ---
    cat > ~/.config/waybar/style.css << 'EOF'
/* ── Тёплая монохромная тема Waybar ── */

* {
    font-family: "JetBrainsMono Nerd Font";
    font-size:   13px;
    min-height:  0;
    border:      none;
    border-radius: 0;
}

window#waybar {
    background-color: #1a1814;
    color:            #e8dcc8;
    transition:       background-color 0.3s ease;
}

window#waybar.hidden { opacity: 0.2; }

#workspaces button {
    padding:          0 6px;
    background-color: transparent;
    color:            #8a8070;
    border-bottom:    3px solid transparent;
}

#workspaces button:hover {
    background:   #2c2820;
    color:        #e8dcc8;
    border-bottom: 3px solid #c8a870;
}

#workspaces button.focused {
    background:    #2c2820;
    color:         #e8dcc8;
    border-bottom: 3px solid #c8a870;
}

#workspaces button.urgent {
    background-color: #c87050;
    color: #1a1814;
}

#mode {
    background-color: #3d3830;
    border-bottom:    3px solid #c8a870;
}

#clock, #battery, #cpu, #memory, #temperature,
#network, #pulseaudio, #tray, #mode, #scratchpad {
    padding:          0 10px;
    color:            #e8dcc8;
    background-color: #2c2820;
    margin:           3px 2px;
    border-radius:    4px;
}

#battery.charging, #battery.plugged { color: #c8a870; }
#battery.critical:not(.charging)    { color: #c87050; animation: blink 0.5s linear infinite alternate; }

@keyframes blink {
    to { background-color: #c87050; color: #1a1814; }
}

#temperature.critical { background-color: #c87050; }

#tray > .passive  { -gtk-icon-effect: dim; }
#tray > .needs-attention { -gtk-icon-effect: highlight; background-color: #3d3830; }
EOF
}

# ─── КОНФИГ MAKO (уведомления) ───────────────────────────────
write_mako_config() {
    info "Записываю конфиг Mako..."
    cat > ~/.config/mako/config << 'EOF'
# Mako — тёплая ч/б тема
sort=-time
layer=overlay
background-color=#2c2820
width=300
height=110
border-size=2
border-color=#c8a870
border-radius=6
icons=1
max-icon-size=48
default-timeout=5000
ignore-timeout=0
font=JetBrainsMono Nerd Font 10
text-color=#e8dcc8
padding=12

[urgency=low]
border-color=#4a4438

[urgency=normal]
border-color=#c8a870

[urgency=high]
border-color=#c87050
background-color=#3d2820
EOF
}

# ─── КОНФИГ FOOT (терминал) ──────────────────────────────────
write_foot_config() {
    info "Записываю конфиг Foot..."
    cat > ~/.config/foot/foot.ini << 'EOF'
# Foot — тёплая ч/б тема
[main]
font=JetBrainsMono Nerd Font:size=11
dpi-aware=auto

[scrollback]
lines=10000

[cursor]
color=1a1814 c8a870
blink=yes

[mouse]
hide-when-typing=yes

[colors]
# Тёплая монохромная палитра
background=1a1814
foreground=e8dcc8
alpha=0.95

# regular
regular0=2c2820
regular1=c87050
regular2=8aac70
regular3=c8a870
regular4=7090a8
regular5=a870a8
regular6=70a8a8
regular7=c8b898

# bright
bright0=4a4438
bright1=d08868
bright2=9abc80
bright3=d8b878
bright4=80a0b8
bright5=b880b8
bright6=80b8b8
bright7=e8dcc8

[key-bindings]
scrollback-up-page=Shift+Page_Up
scrollback-down-page=Shift+Page_Down
clipboard-copy=Control+Shift+c
clipboard-paste=Control+Shift+v
EOF
}

# ─── КОНФИГ SWAYLOCK ─────────────────────────────────────────
write_swaylock_config() {
    info "Записываю конфиг Swaylock..."
    cat > ~/.config/swaylock/config << 'EOF'
# Swaylock — тёплая ч/б тема
daemonize
ignore-empty-password
show-failed-attempts

color=1a1814

ring-color=c8a870
ring-ver-color=8aac70
ring-wrong-color=c87050
ring-clear-color=4a4438

key-hl-color=c8a870
bs-hl-color=c87050

line-color=00000000
line-ver-color=00000000
line-wrong-color=00000000
line-clear-color=00000000

inside-color=2c282066
inside-ver-color=2c282066
inside-wrong-color=c8705033
inside-clear-color=2c282066

text-color=e8dcc8
text-ver-color=e8dcc8
text-wrong-color=c87050
text-clear-color=8a8070

separator-color=00000000
indicator-radius=80
indicator-thickness=6
font=JetBrainsMono Nerd Font
EOF
}

# ─── GTK ТЕМА (тёплая) ───────────────────────────────────────
write_gtk_config() {
    info "Настраиваю GTK тему..."
    mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

    cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=true
gtk-button-images=false
gtk-menu-images=false
gtk-enable-event-sounds=false
gtk-enable-input-feedback-sounds=false
EOF

    cat > ~/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-theme-name=Adwaita-dark
gtk-cursor-theme-name=Adwaita
gtk-font-name=Noto Sans 10
EOF

    # Тёплый оттенок через CSS override
    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/gtk.css << 'EOF'
/* Тёплый тёмный оттенок поверх Adwaita-dark */
@define-color theme_bg_color  #1a1814;
@define-color theme_fg_color  #e8dcc8;
@define-color theme_base_color #2c2820;
@define-color theme_selected_bg_color #c8a870;
@define-color theme_selected_fg_color #1a1814;
EOF
}

# ─── SYSTEMD ЮНИТ ────────────────────────────────────────────
setup_systemd() {
    info "Включаю системные сервисы..."
    systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
}

# ─── XDGET-USER-DIRS ─────────────────────────────────────────
setup_user_dirs() {
    xdg-user-dirs-update
    mkdir -p ~/Pictures ~/Downloads ~/Documents ~/Music ~/Videos
}

# ─── ГЛАВНАЯ ФУНКЦИЯ ─────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║   CachyOS Sway Setup — Тёплая ч/б тема          ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""

    install_packages
    setup_dirs
    write_sway_config
    write_waybar_config
    write_mako_config
    write_foot_config
    write_swaylock_config
    write_gtk_config
    setup_systemd
    setup_user_dirs

    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  ✅ Установка завершена!                         ║"
    echo "║                                                  ║"
    echo "║  Запусти: exec sway                              ║"
    echo "║  или выбери Sway в менеджере входа               ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
    echo "Горячие клавиши:"
    echo "  Super+Enter     — терминал (foot)"
    echo "  Super+D         — лаунчер (wmenu)"
    echo "  Super+Shift+Q   — закрыть окно"
    echo "  Super+L         — заблокировать экран"
    echo "  Super+V         — история буфера обмена"
    echo "  Print            — скриншот"
    echo "  Super+Print      — скриншот области"
    echo "  CapsLock         — смена раскладки (EN/RU)"
}

main "$@"
