#!/usr/bin/env bash
# =============================================================================
#  install.sh — Sway setup для CachyOS + NVIDIA
#  Тема: тёплый ЧБ | Caps Lock → смена языка
# =============================================================================

set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${YELLOW}  $*${NC}"; \
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ───────────────────────────── ПРОВЕРКИ ──────────────────────────────────────
[[ "$EUID" -eq 0 ]] && error "Не запускай от root! Запусти обычным пользователем."
command -v pacman &>/dev/null || error "pacman не найден — это не Arch-based система?"

section "1. Обновление системы"
sudo pacman -Syu --noconfirm

# ───────────────────────────── YAY ───────────────────────────────────────────
section "2. Установка yay (AUR helper)"
if ! command -v yay &>/dev/null; then
    info "Клонируем и собираем yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
else
    info "yay уже установлен, пропускаем."
fi

# ───────────────────────────── ПАКЕТЫ PACMAN ─────────────────────────────────
section "3. Установка основных пакетов из pacman"

PACMAN_PKGS=(
    # === Display Manager ===
    ly

    # === Wayland / Sway ===
    sway
    swaybg
    swayidle
    xorg-xwayland
    qt5-wayland
    qt6-wayland

    # === NVIDIA под Wayland ===
    nvidia
    nvidia-utils
    libva-nvidia-driver
    egl-wayland

    # === Bar ===
    waybar
    otf-font-awesome          # иконки для waybar

    # === Launcher ===
    fuzzel

    # === Уведомления ===
    swaync

    # === Экран блокировки ===
    swaylock

    # === Терминал ===
    foot

    # === Файловый менеджер ===
    thunar
    thunar-volman
    gvfs

    # === Браузер (есть в pacman CachyOS) ===
    zen-browser

    # === Steam / Gaming ===
    steam
    proton-cachyos

    # === Диски ===
    gnome-disk-utility

    # === GTK тема (GUI смена) ===
    nwg-look

    # === Агент паролей (polkit) ===
    polkit-gnome

    # === Буфер обмена ===
    wl-clipboard
    cliphist

    # === Скриншоты ===
    grim
    slurp

    # === Шрифты ===
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji

    # === Системные утилиты ===
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    brightnessctl
    playerctl
    network-manager-applet
    pavucontrol
    imv                       # просмотр изображений
    mpv                       # видеоплеер
    htop
    unzip
    p7zip
    wget
    curl
    jq
    python
    python-pip
)

info "Устанавливаем ${#PACMAN_PKGS[@]} пакетов..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# ───────────────────────────── AUR ПАКЕТЫ ────────────────────────────────────
section "4. Установка пакетов из AUR"

AUR_PKGS=(
    swaylock-effects    # swaylock с блюром и эффектами
    wlogout             # меню выхода/перезагрузки
    grimblast-git       # удобная обёртка над grim
    nwg-displays        # GUI управление мониторами
)

info "Устанавливаем AUR пакеты через yay..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

# ───────────────────────────── НАСТРОЙКА ly ──────────────────────────────────
section "5. Настройка ly (Display Manager)"

sudo systemctl enable ly.service
sudo systemctl disable gdm sddm lightdm 2>/dev/null || true

sudo mkdir -p /etc/ly
sudo tee /etc/ly/config.ini > /dev/null << 'EOF'
[ly]
animate = true
animation = matrix
# Тёплый ЧБ — используем ASCII-арт
asterisk = *
EOF

info "ly включён как display manager."

# ───────────────────────────── ДИРЕКТОРИИ КОНФИГОВ ───────────────────────────
section "6. Создание директорий конфигурации"

mkdir -p \
    ~/.config/sway \
    ~/.config/waybar \
    ~/.config/foot \
    ~/.config/fuzzel \
    ~/.config/mako \
    ~/.config/swaync \
    ~/.config/swaylock \
    ~/.config/wlogout \
    ~/.config/gtk-3.0 \
    ~/.config/gtk-4.0 \
    ~/.local/share/themes

# ───────────────────────────── ТЁПЛАЯ ЧБ ТЕМА ────────────────────────────────
# Цветовая палитра используется везде:
# bg:      #1a1814  (очень тёмный тёплый)
# bg1:     #252118  (тёмный тёплый)
# bg2:     #32302a  (тёмный)
# surface: #3d3a33  (поверхности)
# border:  #5c5449  (бордеры)
# fg:      #d4cfc6  (основной текст)
# fg2:     #a89f94  (второй текст)
# fg3:     #7a736a  (третий текст)
# white:   #f0ebe3  (почти белый тёплый)

# ───────────────────────────── КОНФИГ SWAY ───────────────────────────────────
section "7. Конфиг Sway (с поддержкой NVIDIA)"

cat > ~/.config/sway/config << 'SWAYEOF'
# ╔═══════════════════════════════════════════════════════╗
# ║            SWAY CONFIG — CachyOS + NVIDIA             ║
# ║            Тема: тёплый ЧБ                            ║
# ╚═══════════════════════════════════════════════════════╝

# ─── NVIDIA WAYLAND SUPPORT ─────────────────────────────
# Обязательно для NVIDIA
exec_always --no-startup-id nvidia-smi --persistence-mode=1 2>/dev/null || true

# Переменные среды для NVIDIA + Wayland
exec_always {
    systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK
    hash dbus-update-activation-environment 2>/dev/null && \
        dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK
}

# ─── ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ────────────────────────────────
set $mod Mod4

# ─── NVIDIA env (нужно до запуска compositor) ───────────
# (Эти переменные задаются в /etc/environment — см. ниже)

# ─── ЦВЕТА (тёплый ЧБ) ──────────────────────────────────
# class                 border    backgr.   text      indicator child_border
client.focused          #5c5449   #32302a   #f0ebe3   #7a736a   #5c5449
client.focused_inactive #32302a   #252118   #a89f94   #32302a   #32302a
client.unfocused        #252118   #1a1814   #7a736a   #1a1814   #252118
client.urgent           #8a7a6a   #4a4038   #f0ebe3   #8a7a6a   #8a7a6a

# ─── ШРИФТ ──────────────────────────────────────────────
font pango:JetBrainsMono Nerd Font 10

# ─── БАЗОВЫЕ НАСТРОЙКИ ──────────────────────────────────
default_border pixel 2
default_floating_border pixel 2
gaps inner 6
gaps outer 3
smart_gaps on
smart_borders on

# ─── МОНИТОР ────────────────────────────────────────────
# Раскомментируй и настрой под себя:
# output HDMI-A-1 resolution 1920x1080 position 0,0 refresh 144
output * bg #1a1814 solid_color

# ─── КЛАВИАТУРА (Caps Lock = смена языка) ───────────────
input type:keyboard {
    xkb_layout us,ru
    xkb_options grp:caps_toggle,grp_led:caps
    xkb_numlock enabled
}

# ─── ТАЧПАД ─────────────────────────────────────────────
input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
    pointer_accel 0.3
}

# ─── АВТОЗАПУСК ─────────────────────────────────────────
# Агент паролей
exec_always /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Уведомления
exec_always pkill swaync; sleep 0.5; swaync

# Waybar
exec_always pkill waybar; sleep 0.3; waybar

# Буфер обмена
exec_always wl-paste --type text --watch cliphist store
exec_always wl-paste --type image --watch cliphist store

# NetworkManager апплет
exec_always nm-applet --indicator

# Idle / блокировка экрана
exec_always swayidle -w \
    timeout 300 'swaylock' \
    timeout 600 'swaymsg "output * dpms off"' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock'

# ─── ХОТКЕИ — ОСНОВНЫЕ ──────────────────────────────────
set $term foot
set $menu fuzzel
set $browser zen-browser
set $filemanager thunar

# Терминал
bindsym $mod+Return exec $term

# Лаунчер
bindsym $mod+d exec $menu

# Браузер
bindsym $mod+b exec $browser

# Файловый менеджер
bindsym $mod+e exec $filemanager

# Закрыть окно
bindsym $mod+q kill

# Перезагрузить sway
bindsym $mod+Shift+r reload

# Меню выхода
bindsym $mod+Shift+e exec wlogout

# Экран блокировки
bindsym $mod+l exec swaylock

# Скриншот всего экрана
bindsym Print exec grimblast copy screen

# Скриншот области
bindsym $mod+Print exec grimblast copy area

# Центр уведомлений
bindsym $mod+Shift+n exec swaync-client -t -sw

# История буфера обмена
bindsym $mod+v exec cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

# ─── ХОТКЕИ — УПРАВЛЕНИЕ ОКНАМИ ─────────────────────────
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

# Layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+t layout toggle split
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Resize
bindsym $mod+r mode "resize"
mode "resize" {
    bindsym h resize shrink width 10px
    bindsym j resize grow height 10px
    bindsym k resize shrink height 10px
    bindsym l resize grow width 10px
    bindsym Left  resize shrink width 10px
    bindsym Down  resize grow height 10px
    bindsym Up    resize shrink height 10px
    bindsym Right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

# ─── РАБОЧИЕ ПРОСТРАНСТВА ───────────────────────────────
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9
bindsym $mod+Shift+0 move container to workspace number 10

# ─── МЕДИА КЛАВИШИ ──────────────────────────────────────
bindsym XF86AudioRaiseVolume  exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume  exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute         exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86AudioMicMute      exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindsym XF86MonBrightnessUp   exec brightnessctl set 5%+
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86AudioPlay  exec playerctl play-pause
bindsym XF86AudioPrev  exec playerctl previous
bindsym XF86AudioNext  exec playerctl next

# ─── ПРАВИЛА ОКОН ───────────────────────────────────────
for_window [app_id="pavucontrol"]    floating enable, resize set 600 400
for_window [app_id="nm-connection-editor"] floating enable
for_window [app_id="gnome-disks"]   floating enable, resize set 800 600
for_window [title="File Operation Progress"] floating enable
for_window [app_id="nwg-look"]      floating enable
for_window [app_id="wlogout"]       floating enable

# Назначение приложений на воркспейсы
assign [app_id="zen-browser"]        workspace 2
assign [app_id="steam"]              workspace 5
assign [app_id="thunar"]             workspace 3

SWAYEOF

info "Конфиг Sway создан."

# ───────────────────────────── /etc/environment (NVIDIA) ─────────────────────
section "8. NVIDIA Wayland переменные (/etc/environment)"

sudo tee /etc/environment > /dev/null << 'EOF'
# NVIDIA + Wayland
LIBVA_DRIVER_NAME=nvidia
XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER=vulkan
ELECTRON_OZONE_PLATFORM_HINT=wayland
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland;xcb
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
EOF

info "/etc/environment настроен для NVIDIA + Wayland."

# modeset для NVIDIA
if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub 2>/dev/null; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /' \
        /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    info "nvidia-drm.modeset=1 добавлен в GRUB."
fi

# ───────────────────────────── КОНФИГ WAYBAR ─────────────────────────────────
section "9. Конфиг Waybar (тёплый ЧБ)"

cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 4,
    "margin-top": 4,
    "margin-left": 8,
    "margin-right": 8,

    "modules-left":   ["sway/workspaces", "sway/mode", "sway/scratchpad"],
    "modules-center": ["clock"],
    "modules-right":  [
        "pulseaudio", "network", "cpu", "memory",
        "battery", "tray", "custom/notification"
    ],

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": false,
        "format": "{icon}",
        "format-icons": {
            "1": "󰖟",  "2": "󰈹",  "3": "󰉋",
            "4": "󰎆",  "5": "󰓓",
            "urgent": "󰗖", "focused": "", "default": ""
        }
    },
    "sway/mode": { "format": " {}" },
    "sway/scratchpad": {
        "format": "{icon} {count}",
        "show-empty": false,
        "format-icons": ["", ""],
        "tooltip": true,
        "tooltip-format": "{app}: {title}"
    },
    "clock": {
        "format": "󰸗  {:%a, %d %b   %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "locale": "ru_RU.UTF-8"
    },
    "cpu": {
        "format": "󰘚 {usage}%",
        "tooltip": false,
        "interval": 2
    },
    "memory": {
        "format": "󰍛 {}%",
        "interval": 5
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-plugged": "󰚥 {capacity}%",
        "format-icons": ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"]
    },
    "network": {
        "format-wifi": "󰤨 {signalStrength}%",
        "format-ethernet": "󰈀 {ipaddr}",
        "format-disconnected": "󰤭",
        "tooltip-format": "{ifname}: {ipaddr}/{cidr}\n{essid}",
        "on-click": "nm-connection-editor"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰸈",
        "format-icons": {
            "headphone": "󰋋",
            "default": ["󰕿","󰖀","󰕾"]
        },
        "on-click": "pavucontrol"
    },
    "tray": {
        "icon-size": 16,
        "spacing": 8
    },
    "custom/notification": {
        "tooltip": false,
        "format": "{icon}",
        "format-icons": {
            "notification": "󱅫",
            "none": "󰂚",
            "dnd-notification": "󰂛",
            "dnd-none": "󰂛",
            "inhibited-notification": "󱅫",
            "inhibited-none": "󰂚",
            "dnd-inhibited-notification": "󰂛",
            "dnd-inhibited-none": "󰂛"
        },
        "return-type": "json",
        "exec-if": "which swaync-client",
        "exec": "swaync-client -swb",
        "on-click": "swaync-client -t -sw",
        "on-click-right": "swaync-client -d -sw",
        "escape": true
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
/* ── Waybar — тёплый ЧБ ── */
* {
    font-family: "JetBrainsMono Nerd Font", monospace;
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background-color: rgba(26, 24, 20, 0.92);
    color: #d4cfc6;
    border-radius: 10px;
    border: 1px solid #3d3a33;
}

.modules-left, .modules-center, .modules-right {
    padding: 0 4px;
}

#workspaces button {
    padding: 2px 8px;
    background-color: transparent;
    color: #7a736a;
    border-radius: 6px;
    margin: 4px 2px;
    transition: all 0.2s ease;
}
#workspaces button:hover    { background: #32302a; color: #d4cfc6; }
#workspaces button.focused  { background: #3d3a33; color: #f0ebe3; border-bottom: 2px solid #a89f94; }
#workspaces button.urgent   { background: #4a4038; color: #f0ebe3; }

#clock      { color: #f0ebe3; padding: 0 10px; font-weight: bold; }
#cpu        { color: #c8c2b8; padding: 0 8px; }
#memory     { color: #b8b2a8; padding: 0 8px; }
#battery    { color: #d4cfc6; padding: 0 8px; }
#battery.warning  { color: #a89f94; }
#battery.critical { color: #8a7a6a; }
#network    { color: #c4bfb6; padding: 0 8px; }
#pulseaudio { color: #ccc8be; padding: 0 8px; }
#tray       { padding: 0 6px; }

#mode {
    background-color: #3d3a33;
    color: #f0ebe3;
    padding: 2px 8px;
    border-radius: 6px;
    margin: 4px 2px;
}

#custom-notification { padding: 0 8px; color: #a89f94; }

tooltip {
    background: #252118;
    border: 1px solid #5c5449;
    border-radius: 8px;
    color: #d4cfc6;
}
EOF

info "Waybar настроен."

# ───────────────────────────── КОНФИГ FOOT ───────────────────────────────────
section "10. Конфиг foot (терминал)"

cat > ~/.config/foot/foot.ini << 'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
dpi-aware=yes
pad=8x8

[colors]
# Тёплый ЧБ
background=1a1814
foreground=d4cfc6
selection-background=3d3a33
selection-foreground=f0ebe3

regular0=252118
regular1=7a736a
regular2=8a8278
regular3=9a9288
regular4=a89f94
regular5=b8b0a6
regular6=c4bfb6
regular7=d4cfc6

bright0=3d3a33
bright1=8a8278
bright2=9a9288
bright3=aaa298
bright4=b8b0a6
bright5=c8c2b8
bright6=d4cfc6
bright7=f0ebe3

cursor=d4cfc6
cursor-text=1a1814

[scrollback]
lines=10000

[mouse]
hide-when-typing=yes

[key-bindings]
clipboard-copy=Control+Shift+c
clipboard-paste=Control+Shift+v
EOF

info "Конфиг foot создан."

# ───────────────────────────── КОНФИГ FUZZEL ─────────────────────────────────
section "11. Конфиг Fuzzel (лаунчер)"

cat > ~/.config/fuzzel/fuzzel.ini << 'EOF'
[main]
font=JetBrainsMono Nerd Font:size=13
prompt=  
terminal=foot -e
layer=overlay
width=35
lines=10
tabs=4
horizontal-pad=20
vertical-pad=12
inner-pad=8
image-size-ratio=0.5
anchor=center
exit-on-keyboard-focus-loss=no

[colors]
background=1a1814f0
text=d4cfc6ff
match=f0ebe3ff
selection=32302aff
selection-text=f0ebe3ff
selection-match=f0ebe3ff
border=5c5449ff

[border]
width=1
radius=10

[dmenu]
exit-immediately-if-empty=yes
EOF

info "Конфиг Fuzzel создан."

# ───────────────────────────── КОНФИГ SWAYNC ─────────────────────────────────
section "12. Конфиг SwayNC (уведомления)"

# Копируем дефолтный конфиг если не существует
if [ -f /etc/xdg/swaync/config.json ]; then
    cp /etc/xdg/swaync/config.json ~/.config/swaync/config.json
fi

cat > ~/.config/swaync/style.css << 'EOF'
/* ── SwayNC — тёплый ЧБ ── */
* { color: #d4cfc6; }

.notification-row { outline: none; }

.notification-row:focus,
.notification-row:hover {
    background: #32302a;
    border-radius: 10px;
}

.notification {
    background: #252118;
    border: 1px solid #3d3a33;
    border-radius: 10px;
    padding: 8px;
    margin: 6px 12px;
}

.notification-content { padding: 6px; }

.notification-default-action {
    background: transparent;
    border-radius: 8px;
    margin: 4px;
    padding: 6px;
}

.notification-default-action:hover { background: #32302a; }

.notification-action {
    background: #32302a;
    border: 1px solid #3d3a33;
    border-radius: 6px;
    color: #d4cfc6;
    margin: 2px;
    padding: 4px 8px;
}
.notification-action:hover { background: #3d3a33; }

.close-button {
    background: transparent;
    color: #7a736a;
    border-radius: 100%;
    margin: 4px;
    padding: 2px;
}
.close-button:hover { background: #3d3a33; color: #f0ebe3; }

.notification-label { font-weight: bold; color: #f0ebe3; }
.notification-time   { color: #7a736a; font-size: 11px; }
.notification-body   { color: #d4cfc6; }

.control-center {
    background: #1a1814;
    border: 1px solid #3d3a33;
    border-radius: 12px;
    padding: 8px;
}

.notification-urgent { border-left: 3px solid #a89f94; }
.notification-low    { border-left: 3px solid #5c5449; }
.notification-normal { border-left: 3px solid #7a736a; }
EOF

info "Конфиг SwayNC создан."

# ───────────────────────────── КОНФИГ SWAYLOCK ───────────────────────────────
section "13. Конфиг Swaylock-effects"

cat > ~/.config/swaylock/config << 'EOF'
# ── Swaylock — тёплый ЧБ ──
ignore-empty-password
show-failed-attempts
daemonize

# Эффект блюра
effect-blur=7x5
effect-greyscale

# Цвета
color=1a1814
inside-color=252118aa
ring-color=5c5449ff
key-hl-color=d4cfc6ff
bs-hl-color=8a7a6aff
line-color=00000000

inside-wrong-color=4a4038aa
ring-wrong-color=7a736aff
inside-ver-color=32302aaa
ring-ver-color=a89f94ff

text-color=d4cfc6ff
text-wrong-color=f0ebe3ff
text-ver-color=a89f94ff

# Кольцо
ring-width=3

# Шрифт
font=JetBrainsMono Nerd Font
font-size=18
EOF

info "Конфиг swaylock создан."

# ───────────────────────────── КОНФИГ WLOGOUT ────────────────────────────────
section "14. Конфиг wlogout"

cat > ~/.config/wlogout/layout << 'EOF'
{
    "label": "lock",
    "action": "swaylock",
    "text": "Блокировка",
    "keybind": "l"
}
{
    "label": "hibernate",
    "action": "systemctl hibernate",
    "text": "Гибернация",
    "keybind": "h"
}
{
    "label": "logout",
    "action": "swaymsg exit",
    "text": "Выход",
    "keybind": "e"
}
{
    "label": "shutdown",
    "action": "systemctl poweroff",
    "text": "Выключение",
    "keybind": "s"
}
{
    "label": "suspend",
    "action": "systemctl suspend",
    "text": "Сон",
    "keybind": "u"
}
{
    "label": "reboot",
    "action": "systemctl reboot",
    "text": "Перезагрузка",
    "keybind": "r"
}
EOF

cat > ~/.config/wlogout/style.css << 'EOF'
* {
    background-image: none;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
}

window {
    background-color: rgba(26, 24, 20, 0.9);
}

button {
    color: #d4cfc6;
    background-color: #252118;
    border-radius: 10px;
    border: 1px solid #3d3a33;
    margin: 12px;
    padding: 20px;
    transition: all 0.2s ease;
}

button:focus, button:active, button:hover {
    background-color: #32302a;
    border-color: #5c5449;
    color: #f0ebe3;
    outline: none;
}
EOF

info "Конфиг wlogout создан."

# ───────────────────────────── GTK ТЕМА ──────────────────────────────────────
section "15. GTK настройки (тёплый ЧБ)"

# Используем Adwaita (встроена) с кастомными цветами
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_SMALL_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

cat > ~/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOF

# Тёплые цвета поверх Adwaita через CSS
mkdir -p ~/.config/gtk-4.0
cat > ~/.config/gtk-4.0/gtk.css << 'EOF'
/* Тёплый ЧБ оверрайд для GTK4 */
@define-color accent_color #a89f94;
@define-color accent_bg_color #3d3a33;
@define-color accent_fg_color #f0ebe3;
@define-color window_bg_color #1a1814;
@define-color window_fg_color #d4cfc6;
@define-color view_bg_color #252118;
@define-color view_fg_color #d4cfc6;
@define-color headerbar_bg_color #252118;
@define-color headerbar_fg_color #d4cfc6;
@define-color card_bg_color #32302a;
@define-color card_fg_color #d4cfc6;
@define-color popover_bg_color #252118;
@define-color popover_fg_color #d4cfc6;
@define-color sidebar_bg_color #1a1814;
@define-color sidebar_fg_color #d4cfc6;
EOF

# XDG-переменные для GTK
cat >> ~/.profile << 'EOF'

# GTK / Wayland
export GTK_THEME=Adwaita:dark
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24
EOF

info "GTK настройки применены."

# ───────────────────────────── LOCALE ────────────────────────────────────────
section "16. Локаль (ru_RU)"

if ! grep -q "ru_RU.UTF-8" /etc/locale.gen 2>/dev/null; then
    sudo sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen
    sudo locale-gen
    info "Локаль ru_RU.UTF-8 сгенерирована."
fi

# ───────────────────────────── PIPEWIRE ──────────────────────────────────────
section "17. Включение PipeWire"

systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
info "PipeWire запущен."

# ───────────────────────────── ИТОГ ──────────────────────────────────────────
section "✅ Установка завершена!"

echo ""
echo -e "${GREEN}Что было установлено и настроено:${NC}"
echo "  🖥️  sway           — оконный менеджер (с поддержкой NVIDIA)"
echo "  📊  waybar         — панель (тёплый ЧБ)"
echo "  🚀  fuzzel         — лаунчер"
echo "  🔔  swaync         — уведомления + центр уведомлений"
echo "  💻  foot           — терминал"
echo "  📁  thunar         — файловый менеджер"
echo "  🌐  zen-browser    — браузер"
echo "  🎮  steam          — Steam + proton-cachyos"
echo "  💾  gnome-disks    — управление дисками"
echo "  🔒  swaylock       — экран блокировки с блюром"
echo "  🎨  nwg-look       — смена GTK тем (GUI)"
echo "  🔑  polkit-gnome   — агент паролей"
echo "  📋  cliphist       — история буфера обмена"
echo "  📷  grim+slurp     — скриншоты"
echo "  🖥️  ly             — display manager"
echo ""
echo -e "${YELLOW}Горячие клавиши:${NC}"
echo "  Super+Return     → терминал"
echo "  Super+D          → лаунчер"
echo "  Super+B          → браузер"
echo "  Super+E          → файловый менеджер"
echo "  Super+L          → блокировка"
echo "  Super+Shift+E    → меню выхода"
echo "  Super+Shift+N    → центр уведомлений"
echo "  Super+V          → история буфера"
echo "  Print            → скриншот экрана"
echo "  Super+Print      → скриншот области"
echo "  CapsLock         → смена языка EN/RU"
echo ""
echo -e "${YELLOW}ВАЖНО:${NC}"
echo "  1. Перезагрузи систему: sudo reboot"
echo "  2. После входа запусти nwg-look для выбора GTK темы"
echo "  3. Настрой мониторы в ~/.config/sway/config (раздел output)"
echo "  4. При проблемах с NVIDIA проверь: WLR_NO_HARDWARE_CURSORS=1"
echo ""
echo -e "${GREEN}Перезагружаемся? [y/N]${NC}"
read -r ans
[[ "$ans" =~ ^[Yy]$ ]] && sudo reboot
