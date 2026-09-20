#!/bin/bash

#==============================================================================
# CachyOS Post-Install Setup Script v4.1
# Разработано под жесткие требования: надежность, строгий стиль, без синевы.
#==============================================================================

set -o pipefail

readonly SCRIPT_VERSION="4.1"
readonly LOG_DIR="$HOME/.cache/cachyos-setup"
readonly LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="$LOG_DIR/backups/$(date +%Y%m%d-%H%M%S)"
readonly STATE_FILE="$LOG_DIR/state"

ERRORS=0
WARNINGS=0
SKIPPED=0

if [[ -t 1 ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly CYAN=$'\033[0;36m'
    readonly BLUE=$'\033[0;34m'
    readonly BOLD=$'\033[1m'
    readonly NC=$'\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' CYAN='' BLUE='' BOLD='' NC=''
fi

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$STATE_FILE"

strip_ansi() {
    sed -u 's/\x1b\[[0-9;]*m//g'
}

exec > >(tee >(strip_ansi >> "$LOG_FILE"))
exec 2> >(tee >(strip_ansi >> "$LOG_FILE") >&2)

log_info()    { echo "${CYAN}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS+1)); }
log_error()   { echo "${RED}[ERROR]${NC} $1"; ERRORS=$((ERRORS+1)); }
log_skip()    { echo "${BLUE}[SKIP]${NC} $1"; SKIPPED=$((SKIPPED+1)); }
log_header()  {
    echo ""
    echo "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
    echo "${BOLD}  $1${NC}"
    echo "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
    echo ""
}

SUDO_KEEPER_PID=""
cleanup_on_exit() {
    local exit_code=$?
    [[ -n "$SUDO_KEEPER_PID" ]] && kill "$SUDO_KEEPER_PID" 2>/dev/null
    exit "$exit_code"
}
handle_interrupt() {
    echo ""
    log_warn "Прерывание пользователем"
    cleanup_on_exit
}
trap cleanup_on_exit EXIT
trap handle_interrupt INT TERM

# Глобальные переменные настроек
USER_LANG_SWITCH="grp:caps_toggle"

#==============================================================================
# Утилиты
#==============================================================================

safe_read() {
    local prompt="$1" default="$2" var_name="$3" input=""
    if ! read -rp "$prompt" input; then
        input="$default"
    fi
    input="${input:-$default}"
    printf -v "$var_name" '%s' "$input"
}

mark_done() {
    grep -qxF "$1" "$STATE_FILE" 2>/dev/null || echo "$1" >> "$STATE_FILE"
}

is_done() {
    grep -qxF "$1" "$STATE_FILE" 2>/dev/null
}

should_run() {
    local step="$1"
    if is_done "$step"; then
        local answer=""
        safe_read "Шаг '$step' уже выполнялся. Пропустить? [Y/n]: " "Y" answer
        if [[ "$answer" =~ ^[YyДд]$|^$ ]]; then
            log_skip "$step"
            return 1
        fi
    fi
    return 0
}

backup_file() {
    local file="$1"
    if [[ -e "$file" ]]; then
        local rel="${file#$HOME/}"
        rel="${rel#/}"
        local target="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$target")"
        cp -a "$file" "$target" 2>/dev/null && log_info "Бэкап создан: $file"
    fi
}

safe_write() {
    local target="$1" content="$2"
    if [[ -f "$target" ]]; then
        local current
        current=$(cat "$target" 2>/dev/null)
        if [[ "$current" == "$content" ]]; then
            log_skip "$target уже соответствует конфигурации"
            return 0
        fi
        backup_file "$target"
    fi
    mkdir -p "$(dirname "$target")"
    if printf '%s\n' "$content" > "$target"; then
        log_success "Файл записан: $target"
        return 0
    else
        log_error "Ошибка записи: $target"
        return 1
    fi
}

safe_write_root() {
    local target="$1" content="$2"
    if [[ -f "$target" ]]; then
        local current
        current=$(sudo cat "$target" 2>/dev/null)
        if [[ "$current" == "$content" ]]; then
            log_skip "$target уже соответствует конфигурации"
            return 0
        fi
        sudo cp -a "$target" "$target.bak.$(date +%s)" 2>/dev/null
    fi
    sudo mkdir -p "$(dirname "$target")"
    if printf '%s\n' "$content" | sudo tee "$target" > /dev/null; then
        log_success "Системный файл записан: $target"
        return 0
    else
        log_error "Ошибка записи системного файла: $target"
        return 1
    fi
}

pkg_in_repo() { pacman -Si "$1" &>/dev/null; }
pkg_installed() { pacman -Qi "$1" &>/dev/null; }

install_pacman_pkgs() {
    local -a pkgs=("$@") to_install=()
    for pkg in "${pkgs[@]}"; do
        pkg_installed "$pkg" && continue
        if pkg_in_repo "$pkg"; then
            to_install+=("$pkg")
        else
            log_warn "Пакет '$pkg' не найден в репозиториях"
        fi
    done
    if [[ ${#to_install[@]} -eq 0 ]]; then
        return 0
    fi
    log_info "Установка пакетов: ${to_install[*]}"
    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        return 0
    else
        log_error "Ошибка установки пакетов через pacman"
        return 1
    fi
}

install_aur_pkg() {
    local pkg="$1"
    pkg_installed "$pkg" && return 0
    command -v yay &>/dev/null || { log_error "yay не найден!"; return 1; }
    log_info "Установка из AUR: $pkg"
    if yay -S --needed --noconfirm "$pkg"; then
        return 0
    else
        log_warn "Не удалось установить $pkg из AUR"
        return 1
    fi
}

install_smart() {
    local pkg="$1"
    pkg_installed "$pkg" && return 0
    if pkg_in_repo "$pkg"; then
        install_pacman_pkgs "$pkg"
    else
        install_aur_pkg "$pkg"
    fi
}

#==============================================================================
# PREFLIGHT
#==============================================================================
preflight_checks() {
    log_header "Проверки системы"

    [[ $EUID -eq 0 ]] && { log_error "Не запускайте скрипт от имени root!"; exit 1; }
    command -v pacman &>/dev/null || { log_error "Это не Arch-based система!"; exit 1; }
    sudo -v || { log_error "Нужен доступ к sudo!"; exit 1; }

    # Sudo keeper
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPER_PID=$!

    # Проверка интернета
    ping -c 1 -W 3 archlinux.org &>/dev/null || { log_error "Нет подключения к интернету!"; exit 1; }

    log_success "Базовые проверки пройдены"
}

#==============================================================================
# НАСТРОЙКА КЛАВИАТУРЫ (ИНТЕРАКТИВНО)
#==============================================================================
configure_keyboard_layout() {
    log_header "Настройка переключения языков"

    echo "${BOLD}Выберите клавишу смены раскладки (US/RU):${NC}"
    echo "  1) CapsLock (По умолчанию)"
    echo "  2) Alt+Shift"
    echo "  3) Ctrl+Shift"
    echo "  4) Super+Space"

    local choice=""
    safe_read "Выбор [1-4, по умолчанию 1]: " "1" choice

    case "$choice" in
        2) USER_LANG_SWITCH="grp:alt_shift_toggle" ;;
        3) USER_LANG_SWITCH="grp:ctrl_shift_toggle" ;;
        4) USER_LANG_SWITCH="grp:win_space_toggle" ;;
        *) USER_LANG_SWITCH="grp:caps_toggle" ;;
    esac

    log_success "Выбрана схема переключения: $USER_LANG_SWITCH"
}

#==============================================================================
# УСТАНОВКА YAY
#==============================================================================
install_yay() {
    log_header "Установка AUR-помощника (yay)"
    should_run "install_yay" || return 0

    if command -v yay &>/dev/null; then
        log_success "yay уже установлен"
        mark_done "install_yay"
        return 0
    fi

    install_pacman_pkgs base-devel git || return 1

    local tmpdir
    tmpdir=$(mktemp -d)
    if ! git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"; then
        rm -rf "$tmpdir"; log_error "Не удалось клонировать репозиторий yay-bin"; return 1
    fi

    if (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm); then
        log_success "yay успешно установлен"
        mark_done "install_yay"
    else
        log_error "Ошибка сборки yay"
    fi
    rm -rf "$tmpdir"
}

#==============================================================================
# ВКЛЮЧЕНИЕ MULTILIB
#==============================================================================
enable_multilib() {
    log_header "Включение репозитория multilib"
    should_run "enable_multilib" || return 0

    if pacman -Sl multilib &>/dev/null; then
        log_skip "multilib уже активен"
        mark_done "enable_multilib"
        return 0
    fi

    backup_file /etc/pacman.conf

    if sudo awk '
        /^#\[multilib\]/ {
            print substr($0, 2); getline
            if ($0 ~ /^#Include/) { print substr($0, 2); next }
            print; next
        }
        { print }
    ' /etc/pacman.conf | sudo tee /etc/pacman.conf.new > /dev/null; then
        sudo mv /etc/pacman.conf.new /etc/pacman.conf
        sudo pacman -Sy --noconfirm
        log_success "multilib успешно включен"
        mark_done "enable_multilib"
    else
        log_error "Не удалось изменить /etc/pacman.conf"
        return 1
    fi
}

#==============================================================================
# ДРАЙВЕРЫ И ПОДДЕРЖКА NVIDIA
#==============================================================================
install_gpu_drivers() {
    log_header "Установка GPU драйверов"
    should_run "install_gpu_drivers" || return 0

    local lspci_out
    lspci_out=$(lspci)
    local -a pkgs=(vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-utils)

    if grep -qi "nvidia" <<< "$lspci_out"; then
        log_info "Обнаружена видеокарта NVIDIA. Установка проприетарных драйверов dkms..."
        pkgs+=(nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings egl-wayland)

        # Конфигурация ядра для правильной работы Wayland на NVIDIA
        local nvidia_conf="options nvidia_drm modeset=1 fbdev=1"
        safe_write_root /etc/modprobe.d/nvidia.conf "$nvidia_conf"

        if [[ -f /etc/mkinitcpio.conf ]]; then
            backup_file /etc/mkinitcpio.conf
            sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
            log_info "Модули NVIDIA добавлены в mkinitcpio.conf. Пересборка образов..."
            sudo mkinitcpio -P
        fi
    fi

    if grep -qiE "amd|radeon" <<< "$lspci_out"; then
        log_info "Обнаружена видеокарта AMD. Установка драйверов..."
        pkgs+=(vulkan-radeon lib32-vulkan-radeon mesa lib32-mesa libva-mesa-driver lib32-libva-mesa-driver)
    fi

    if grep -qi "intel" <<< "$lspci_out"; then
        log_info "Обнаружено графическое ядро Intel. Установка драйверов..."
        pkgs+=(vulkan-intel lib32-vulkan-intel mesa lib32-mesa intel-media-driver)
    fi

    install_pacman_pkgs "${pkgs[@]}"
    mark_done "install_gpu_drivers"
}

#==============================================================================
# УСТАНОВКА ОКРУЖЕНИЯ SWAY И ЭЛЕМЕНТОВ DE
#==============================================================================
install_sway() {
    log_header "Установка Sway и компонентов полноценного DE"
    should_run "install_sway" || return 0

    # Устанавливаем все нужные утилиты для DE (автомонтирование, буфер обмена, скриншоты)
    local -a packages=(
        sway swaybg swaylock swayidle
        waybar fuzzel foot mako
        grim slurp wl-clipboard cliphist
        wlr-randr kanshi
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-utils
        polkit-gnome
        brightnessctl playerctl pamixer
        network-manager-applet blueman
        pipewire pipewire-pulse pipewire-alsa wireplumber
        pavucontrol
        qt5-wayland qt6-wayland
        libinput
        udisks2 udevil            # Для автомонтирования (devmon)
        swappy                    # Графический редактор скриншотов
        xorg-xcursorgen           # Для генерации пиксельной точки-курсора
    )

    install_pacman_pkgs "${packages[@]}"

    # Включение PipeWire
    if command -v systemctl &>/dev/null; then
        systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null
    fi

    mark_done "install_sway"
}

#==============================================================================
# РУЧНАЯ СБОРКА ИНФОРМАТИВНОГО КУРСОР-ТОЧКИ (100% OFFLINE)
#==============================================================================
generate_dot_cursor() {
    log_header "Сборка информативного курсора-точки"
    should_run "generate_dot_cursor" || return 0

    # Создаем временную директорию для сборки курсора
    local cur_dir
    cur_dir=$(mktemp -d)

    # 16x16 PNG файл точки (белый центр 3х3, черная обводка 5х5, хотспот ровно по центру 8,8)
    # Закодирован в base64 для независимости от сторонних загрузок
    local png_b64="iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAMklEQVQ4T2N89f79fwYgYGRgYBhgAEK6SsbYAC6AYgNDXUDIAPLSgG4G0M0ArbMBXAEA6scW8fG0E6IAAAAASUVORK5CYII="

    echo "$png_b64" | base64 -d > "$cur_dir/dot.png"

    # Пишем конфиг для xcursorgen
    echo "16 8 8 dot.png" > "$cur_dir/dot.cursor"

    # Генерируем бинарный файл курсора
    mkdir -p ~/.icons/Adwaita/cursors
    if xcursorgen "$cur_dir/dot.cursor" ~/.icons/Adwaita/cursors/left_ptr; then
        # Делаем симлинки для основных типов указателей, чтобы курсор оставался информативным
        # При ресайзе окон или выделении текста курсор БУДЕТ меняться на стандартные стрелочки
        cd ~/.icons/Adwaita/cursors || return 1
        ln -sf left_ptr default
        ln -sf left_ptr arrow
        ln -sf left_ptr pointer

        # Пишем конфиг для дефолтных иконок
        mkdir -p ~/.icons/default
        safe_write ~/.icons/default/index.theme "[Icon Theme]
Inherits=Adwaita"

        log_success "Курсор-точка собран и установлен в ~/.icons/Adwaita"
        mark_done "generate_dot_cursor"
    else
        log_error "Не удалось сгенерировать курсор-точку. Будет использован стандартный."
    fi

    rm -rf "$cur_dir"
}

#==============================================================================
# ДОПОЛНИТЕЛЬНЫЕ ПРОГРАММЫ
#==============================================================================
install_file_manager() {
    log_header "Настройка файлового менеджера"
    should_run "install_file_manager" || return 0
    # Ставим Thunar с поддержкой корзины, дисков и архиватора (как в нормальном DE)
    install_pacman_pkgs thunar thunar-volman thunar-archive-plugin gvfs gvfs-mtp tumbler file-roller
    mark_done "install_file_manager"
}

install_zen_browser() {
    log_header "Установка Zen Browser"
    should_run "install_zen_browser" || return 0
    install_smart zen-browser-bin || install_smart zen-browser
    mark_done "install_zen_browser"
}

install_gaming() {
    log_header "Установка Steam & Gaming"
    should_run "install_gaming" || return 0
    local ans=""
    safe_read "Установить Steam и игровые утилиты? [y/N]: " "N" ans
    if [[ "$ans" =~ ^[YyДд]$ ]]; then
        install_pacman_pkgs steam gamemode lib32-gamemode mangohud lib32-mangohud gamescope
        install_smart proton-cachyos
        mark_done "install_gaming"
    fi
}

install_extras() {
    log_header "Шрифты и терминальный софт"
    should_run "install_extras" || return 0

    local -a fonts=(ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts noto-fonts-emoji)
    pkg_in_repo noto-fonts-cjk && fonts+=(noto-fonts-cjk)
    pkg_in_repo noto-fonts-cjk-vf && ! pkg_in_repo noto-fonts-cjk && fonts+=(noto-fonts-cjk-vf)

    install_pacman_pkgs "${fonts[@]}" htop btop fastfetch p7zip unrar unzip rsync wget curl bash-completion
    mark_done "install_extras"
}

#==============================================================================
# НАСТРОЙКИ МЫШИ (БЕЗ АКСЕЛЕРАЦИИ)
#==============================================================================
configure_mouse() {
    log_header "Отключение ускорения мыши"
    should_run "configure_mouse" || return 0

    # Отключение акселерации на уровне Xwayland для корректной работы игр
    local xorg_mouse='Section "InputClass"
    Identifier "MouseNoAccel"
    MatchIsPointer "yes"
    Driver "libinput"
    Option "AccelProfile" "flat"
    Option "AccelSpeed" "0"
    Option "MiddleEmulation" "off"
EndSection'

    safe_write_root /etc/X11/xorg.conf.d/30-mouse-noaccel.conf "$xorg_mouse"
    mark_done "configure_mouse"
}

#==============================================================================
# СОЗДАНИЕ КЛАССИЧЕСКИХ ДИРЕКТОРИЙ
#==============================================================================
create_directories() {
    mkdir -p ~/Pictures/Screenshots ~/Downloads ~/Documents ~/Videos ~/Music
}

#==============================================================================
# ГЕНЕРАЦИЯ КОНФИГУРАЦИЙ (БЕЗ СИНЕГО ЦВЕТА, С КОРРЕКТНЫМ FOOT)
#==============================================================================
write_configs() {
    log_header "Запись файлов конфигурации"

    # 1. ТЁПЛАЯ Ч/Б ТЕМА ДЛЯ GTK
    safe_write ~/.config/gtk-3.0/settings.ini "[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=16
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:close"

    safe_write ~/.config/gtk-4.0/settings.ini "[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=16
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1"

    # 2. FOOT ИСПРАВЛЕННЫЙ (БЕЗ КОММЕНТАРИЕВ ВНУТРИ СЕКЦИЙ И СЛОМАННЫХ СТРОК)
    local foot_conf="[main]
font=JetBrains Mono:size=11
dpi-aware=yes
pad=6x6

[scrollback]
lines=10000

[cursor]
style=beam
blink=yes

[mouse]
hide-when-typing=yes

[colors]
background=121212
foreground=e6e1da
regular0=1c1b1a
regular1=cc6666
regular2=a9b665
regular3=d79921
regular4=8a847e
regular5=b16286
regular6=89b482
regular7=e6e1da
bright0=3c3836
bright1=cc6666
bright2=a9b665
bright3=d79921
bright4=8a847e
bright5=b16286
bright6=89b482
bright7=ebdbb2
selection-foreground=e6e1da
selection-background=3c3836"

    safe_write ~/.config/foot/foot.ini "$foot_conf"

    # 3. FUZZEL (БЫСТРЫЙ ЛАУНЧЕР И МЕНЮ ВЫХОДА)
    local fuzzel_conf="[main]
font=JetBrains Mono:size=12
terminal=foot
layer=overlay
prompt=\"> \"
width=40
lines=10

[colors]
background=121212f0
text=e6e1daff
match=d79921ff
selection=3c3836ff
selection-text=ebdbb2ff
border=8a847eff

[border]
width=1
radius=0"

    safe_write ~/.config/fuzzel/fuzzel.ini "$fuzzel_conf"

    # 4. MAKO (АККУРАТНЫЕ УВЕДОМЛЕНИЯ УРОВНЯ DE)
    local mako_conf="sort=-time
layer=overlay
anchor=top-right
width=300
height=100
margin=10
padding=10
border-size=1
border-radius=0
border-color=#8a847e
background-color=#121212f0
text-color=#e6e1da
default-timeout=4000
font=JetBrains Mono 10

[urgency=high]
border-color=#cc6666"

    safe_write ~/.config/mako/config "$mako_conf"

    # 5. КРАСИВЫЙ SWAY CONFIG (ГРАНИЦЫ 1PX, НОРМАЛЬНЫЙ ТАЙЛИНГ, РАБОЧИЕ ХОТКЕИ)
    # Все bindsym используют --to-code, чтобы клавиши работали на ЛЮБОЙ раскладке клавиатуры
    local sway_conf='# SWAY CONFIG v4.1
# Разметка: чистый тайлинг без уродливых заголовков

set $mod Mod4
set $term foot
set $menu fuzzel

font pango:JetBrains Mono 10

# ── Автозапуск компонентов DE ────────────────────────────────
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec waybar
exec mako
exec nm-applet --indicator
exec wl-paste --watch cliphist store
exec devmon --exec-on-drive "thunar %d"   # Автомонтирование флешек и открытие в Thunar

# Скринсейвер / Локер
exec swayidle -w \
    timeout 300 "swaylock -f -c 121212" \
    timeout 600 "swaymsg output * power off" \
    resume "swaymsg output * power on" \
    before-sleep "swaylock -f -c 121212"

# ── Внешний вид (Строгая теплая серая тема, без синевы) ──────
output * bg #121212 solid_color

# Отключение заголовков окон (titlebars), только тонкая рамка 1px
default_border pixel 1
default_floating_border pixel 1
smart_borders off
gaps inner 4
gaps outer 0

# Теплые цвета (border bg text indicator child_border)
client.focused          #8a847e #121212 #e6e1da #8a847e #8a847e
client.focused_inactive #3c3836 #121212 #8a847e #3c3836 #3c3836
client.unfocused        #1c1b1a #121212 #8a847e #1c1b1a #1c1b1a
client.urgent           #cc6666 #121212 #e6e1da #cc6666 #cc6666

# ── Ввод ─────────────────────────────────────────────────────
input type:keyboard {
    xkb_layout us,ru
    xkb_options '"$USER_LANG_SWITCH"'
    repeat_delay 250
    repeat_rate 45
}

# Мышь без ускорения (1:1)
input type:pointer {
    accel_profile flat
    pointer_accel 0
    middle_emulation disabled
}

# Курсор Adwaita (в котором мы скомпилировали точку)
seat seat0 xcursor_theme Adwaita 16

# ── Горячие клавиши (РАБОТАЮТ НА ВСЕХ ЯЗЫКАХ ИЗ-ЗА --to-code) ─
bindsym --to-code $mod+Return exec $term
bindsym --to-code $mod+d exec $menu
bindsym --to-code $mod+q kill
bindsym --to-code $mod+Shift+c reload

# Session menu вместо уродливой стандартной полосы выхода
bindsym --to-code $mod+Shift+e exec sh -c '\''
    choice=$(echo -e "Lock\nSuspend\nReboot\nShutdown" | fuzzel -d -p "Выход: ")
    case "$choice" in
        Lock) swaylock -f -c 121212 ;;
        Suspend) systemctl suspend ;;
        Reboot) systemctl reboot ;;
        Shutdown) systemctl poweroff ;;
    esac
'\''

bindsym --to-code $mod+Escape exec swaylock -f -c 121212

# Буфер обмена (С управлением через fuzzel)
bindsym --to-code $mod+v exec cliphist list | fuzzel -d -p "Буфер: " | cliphist decode | wl-copy

# Скриншоты (Интеграция со Swappy для рисования стрелок на лету)
bindsym Print exec grim - | swappy -f -
bindsym --to-code $mod+Print exec grim -g "$(slurp)" - | swappy -f -

bindsym --to-code $mod+e exec thunar
bindsym --to-code $mod+b exec zen-browser

# Звук и подсветка с OSD-Уведомлениями (как в полноценном DE)
bindsym XF86AudioRaiseVolume exec sh -c '\''pamixer -i 5; vol=$(pamixer --get-volume); makoctl dismiss; notify-send -h string:x-canonical-private-synchronous:volume "Звук: ${vol}%" -h int:value:"$vol"'\''
bindsym XF86AudioLowerVolume exec sh -c '\''pamixer -d 5; vol=$(pamixer --get-volume); makoctl dismiss; notify-send -h string:x-canonical-private-synchronous:volume "Звук: ${vol}%" -h int:value:"$vol"'\''
bindsym XF86AudioMute exec sh -c '\''pamixer -t; notify-send -h string:x-canonical-private-synchronous:volume "Режим звука изменен"'\''
bindsym XF86MonBrightnessUp exec sh -c '\''brightnessctl set +5%; br=$(light -G 2>/dev/null || brightnessctl -m | cut -d, -f4 | tr -d "%"); makoctl dismiss; notify-send -h string:x-canonical-private-synchronous:brightness "Яркость: ${br}%" -h int:value:"$br"'\''
bindsym XF86MonBrightnessDown exec sh -c '\''brightnessctl set 5%-; br=$(light -G 2>/dev/null || brightnessctl -m | cut -d, -f4 | tr -d "%"); makoctl dismiss; notify-send -h string:x-canonical-private-synchronous:brightness "Яркость: ${br}%" -h int:value:"$br"'\''

# ── Нормальная навигация окон (тайлинг рядом) ───────────────
bindsym --to-code $mod+h focus left
bindsym --to-code $mod+j focus down
bindsym --to-code $mod+k focus up
bindsym --to-code $mod+l focus right

bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

bindsym --to-code $mod+Shift+h move left
bindsym --to-code $mod+Shift+j move down
bindsym --to-code $mod+Shift+k move up
bindsym --to-code $mod+Shift+l move right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Сплиты
bindsym --to-code $mod+comma splith
bindsym --to-code $mod+period splitv

bindsym --to-code $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# Воркспейсы
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

# Режим изменения размера окон
mode "resize" {
    bindsym --to-code h resize shrink width 25px
    bindsym --to-code j resize grow height 25px
    bindsym --to-code k resize shrink height 25px
    bindsym --to-code l resize grow width 25px
    bindsym Left resize shrink width 25px
    bindsym Down resize grow height 25px
    bindsym Up resize shrink height 25px
    bindsym Right resize grow width 25px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym --to-code $mod+r mode "resize"

# Всплывающие окна всегда в плавающем режиме
for_window [window_role="pop-up"] floating enable
for_window [window_role="dialog"] floating enable
for_window [window_type="dialog"] floating enable
for_window [app_id="pavucontrol"] floating enable
for_window [app_id="nm-connection-editor"] floating enable

xwayland enable'

    safe_write ~/.config/sway/config "$sway_conf"

    # 6. WAYBAR (БЕЗ СПИСКА ОТКРЫТЫХ ОКОН, ЧИСТЫЙ ТЁПЛЫЙ ВИД)
    local waybar_conf='{
    "layer": "top",
    "position": "top",
    "height": 26,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "pulseaudio", "network", "cpu", "memory", "battery", "sway/language"],

    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "sway/mode": { "format": "<span style=\"italic\">{}</span>" },
    "sway/language": {
        "format": "{}",
        "on-click": "swaymsg input type:keyboard xkb_switch_layout next"
    },
    "clock": {
        "format": "{:%H:%M  %d.%m.%y}"
    },
    "cpu": { "format": "cpu {usage}%", "interval": 5 },
    "memory": { "format": "mem {percentage}%", "interval": 5 },
    "battery": {
        "format": "bat {capacity}%",
        "format-charging": "chr {capacity}%"
    },
    "network": {
        "format-wifi": "wifi {signalStrength}%",
        "format-ethernet": "eth",
        "format-disconnected": "offline"
    },
    "pulseaudio": {
        "format": "vol {volume}%",
        "format-muted": "mute",
        "on-click": "pavucontrol"
    },
    "tray": { "spacing": 6 }
}'
    safe_write ~/.config/waybar/config.jsonc "$waybar_conf"
    ln -sf config.jsonc ~/.config/waybar/config 2>/dev/null

    local waybar_style='* {
    font-family: "JetBrains Mono";
    font-size: 11px;
}
window#waybar {
    background-color: #121212;
    color: #e6e1da;
    border-bottom: 1px solid #3c3836;
}
#workspaces button {
    padding: 0 8px;
    color: #8a847e;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
}
#workspaces button.focused {
    color: #e6e1da;
    border-bottom: 2px solid #8a847e;
}
#workspaces button.urgent {
    color: #cc6666;
}
#clock, #battery, #cpu, #memory, #network, #pulseaudio, #language, #tray {
    padding: 0 8px;
}'
    safe_write ~/.config/waybar/style.css "$waybar_style"
}

#==============================================================================
# АВТОЗАПУСК И ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
#==============================================================================
setup_environment() {
    log_header "Запись автозапуска и переменных окружения"
    should_run "setup_environment" || return 0

    local nvidia_vars=""
    if lspci | grep -qi "nvidia"; then
        nvidia_vars='
# NVIDIA WAYLAND FIX
export WLR_NO_HARDWARE_CURSORS=1
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export LIBVA_DRIVER_NAME=nvidia'
    fi

    # Глобальные переменные окружения
    local env_conf="XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=sway
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
QT_AUTO_SCREEN_SCALE_FACTOR=1
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=auto
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=16
_JAVA_AWT_WM_NONREPARENTING=1"

    safe_write ~/.config/environment.d/sway.conf "$env_conf"

    # .bash_profile с поддержкой запуска на видеокартах NVIDIA
    backup_file ~/.bash_profile
    cat > ~/.bash_profile << EOF
# BASH PROFILE — AUTOSTART SWAY WITH NVIDIA BYPASS
if [ -z "\$WAYLAND_DISPLAY" ] && [ -z "\$DISPLAY" ] && [ "\${XDG_VTNR:-0}" -eq 1 ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=sway
    export QT_QPA_PLATFORM=wayland
    export QT_QPA_PLATFORMTHEME=qt5ct
    export MOZ_ENABLE_WAYLAND=1
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export XCURSOR_THEME=Adwaita
    export XCURSOR_SIZE=16
    export _JAVA_AWT_WM_NONREPARENTING=1
    export sway_unsupported_gpu=true
    export WLR_NO_HARDWARE_CURSORS=1
    ${nvidia_vars}
    
    # Запуск с флагом неподдерживаемой видеокарты (NVIDIA FIX)
    exec sway --unsupported-gpu
fi
EOF

    log_success "Автозапуск настроен"
    mark_done "setup_environment"
}

#==============================================================================
# ГЛАВНЫЙ ЗАПУСК
#==============================================================================
main() {
    clear
    echo "${BOLD}${CYAN}"
    cat << BANNER
   ╔═══════════════════════════════════════════════╗
   ║      CachyOS Sway Setup Script v${SCRIPT_VERSION}           ║
   ║   Тайлинг • Строгий Ч/Б Дизайн • NVIDIA Фикс  ║
   ╚═══════════════════════════════════════════════╝
BANNER
    echo "${NC}"

    preflight_checks
    configure_keyboard_layout

    install_yay              || true
    enable_multilib          || true
    install_gpu_drivers      || true
    install_sway             || true
    generate_dot_cursor      || true
    install_file_manager     || true
    install_zen_browser      || true
    install_gaming           || true
    install_extras           || true
    create_directories       || true
    configure_mouse          || true
    write_configs            || true
    setup_environment        || true

    log_header "УСТАНОВКА ЗАВЕРШЕНА!"
    echo "  1. Перезагрузите компьютер (sudo reboot)."
    echo "  2. Sway запустится на 1-м TTY."
    echo "  3. Курсор-точка сгенерирован и активен."
    echo "  4. Тайлинг чистый (без заголовков и лишних элементов)."
    echo ""
    
    local reboot_confirm=""
    safe_read "Перезагрузить систему сейчас? [y/N]: " "N" reboot_confirm
    if [[ "$reboot_confirm" =~ ^[YyДд]$ ]]; then
        sudo reboot
    fi
}

main "$@"
