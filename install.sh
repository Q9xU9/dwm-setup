#!/bin/bash

# Остановить скрипт при ошибке
set -e

echo "--- Установка начата: CachyOS + Sway (NVIDIA Edition) ---"

# 1. Обновление системы и установка yay
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
fi

# 2. Драйверы NVIDIA и необходимые утилиты для Wayland
# Для CachyOS лучше использовать их оптимизированные ядра и драйверы
sudo pacman -S --noconfirm nvidia-cachyos libva-nvidia-driver-git linux-cachyos-headers

# 3. Установка ядра системы (Sway + Ly + Утилиты)
sudo pacman -S --noconfirm \
    sway \
    swaybg \
    swaylock \
    swayidle \
    waybar \
    ly \
    alacritty \
    thunar \
    thunar-archive-plugin \
    grim \
    slurp \
    wl-clipboard \
    mako \
    polkit-gnome \
    adwaita-icon-theme \
    ttf-jetbrains-mono-nerd

# 4. Установка софта пользователя
# Zen Browser (из AUR), Steam, Gnome-disks
yay -S --noconfirm zen-browser-bin
sudo pacman -S --noconfirm steam gnome-disk-utility

# 5. Настройка NVIDIA для работы со Sway
# Создаем файл окружения, чтобы Wayland не лагал на NVIDIA
sudo mkdir -p /etc/sway/env
cat <<EOF | sudo tee /etc/environment
# NVIDIA Fixes
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
EOF

# 6. Создание конфигов (Warm Monochrome Style)
mkdir -p ~/.config/sway
mkdir -p ~/.config/waybar
mkdir -p ~/.config/alacritty

# --- Конфиг Sway ---
cat <<EOF > ~/.config/sway/config
# Переменные
set \$mod Mod4
set \$term alacritty

# Цвета (Warm Monochrome)
set \$black #1a1a1a
set \$white #f2e5bc
set \$gray  #928374

output * bg \$black solid

# Оформление окон
default_border pixel 2
client.focused \$white \$black \$white \$white \$white
client.focused_inactive \$gray \$black \$gray \$gray \$gray

# Бинды
bindsym \$mod+Return exec \$term
bindsym \$mod+q kill
bindsym \$mod+d exec wofi --show run
bindsym \$mod+Shift+e exec swaynag -t warning -m 'Exit Sway?' -b 'Yes' 'swaymsg exit'

# Включение баров
bar {
    swaybar_command waybar
}

# Фикс для NVIDIA (не всегда нужен, но для стабильности)
exec_always "export WLR_NO_HARDWARE_CURSORS=1"
EOF

# --- Конфиг Waybar (Минимализм + Инфо) ---
cat <<EOF > ~/.config/waybar/config
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "battery", "pulseaudio", "tray"],
    "clock": {
        "format": "{:%H:%M | %d.%m}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": { "format": "CPU: {usage}%" },
    "memory": { "format": "RAM: {}%" }
}
EOF

cat <<EOF > ~/.config/waybar/style.css
* {
    border: none;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
}
window#waybar {
    background: #1a1a1a;
    color: #f2e5bc;
    border-bottom: 1px solid #f2e5bc;
}
#workspaces button {
    padding: 0 5px;
    color: #928374;
}
#workspaces button.focused {
    color: #f2e5bc;
}
EOF

# --- Конфиг Alacritty (Warm Black/White) ---
cat <<EOF > ~/.config/alacritty/alacritty.toml
[window]
padding = { x = 10, y = 10 }
opacity = 0.95

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
size = 11.0

[colors.primary]
background = '#1a1a1a'
foreground = '#f2e5bc'

[colors.cursor]
text = '#1a1a1a'
cursor = '#f2e5bc'
EOF

# 7. Финализация
sudo systemctl enable ly

echo "--- Установка завершена! Перезагрузись (reboot) ---"
