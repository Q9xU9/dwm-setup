#!/bin/bash

#==============================================================================
# CachyOS Post-Install Setup Script v4
# Приоритеты: надёжность → производительность → практичность
# v4:
#   - Нормальный тайлинг (окна рядом, не поверх)
#   - Убраны title bars полностью
#   - Тёплая ч/б тема без синих акцентов
#   - Клавиши работают на любой раскладке (--to-code)
#   - Выбор переключения языка (CapsLock / Alt+Shift / и т.д.)
#   - NVIDIA автоустановка
#   - Курсор — маленькая точка (Adwaita 16px)
#   - Убраны assign правила — окна открываются на текущем столе
#==============================================================================

set -o pipefail

readonly SCRIPT_VERSION="4.0"
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
    log_warn "Прервано (Ctrl+C)"
    cleanup_on_exit
}
trap cleanup_on_exit EXIT
trap handle_interrupt INT TERM

# ── Глобальные настройки пользователя (выбираются интерактивно) ──
USER_LANG_SWITCH=""
USER_CURSOR_SIZE="16"
USER_CURSOR_THEME="Adwaita"

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
        cp -a "$file" "$target" 2>/dev/null && log_info "Бэкап: $file"
    fi
}

safe_write() {
    local target="$1" content="$2"
    if [[ -f "$target" ]]; then
        local current
        current=$(cat "$target" 2>/dev/null)
        if [[ "$current" == "$content" ]]; then
            log_skip "$target уже актуален"
            return 0
        fi
        local answer=""
        safe_read "Файл $target существует. Перезаписать? [y/N]: " "N" answer
        if [[ ! "$answer" =~ ^[YyДд]$ ]]; then
            log_skip "Не перезаписан: $target"
            return 1
        fi
        backup_file "$target"
    fi
    mkdir -p "$(dirname "$target")"
    if printf '%s\n' "$content" > "$target"; then
        log_success "Записан: $target"
    else
        log_error "Не удалось записать: $target"
        return 1
    fi
}

safe_write_root() {
    local target="$1" content="$2"
    if [[ -f "$target" ]]; then
        local current
        current=$(sudo cat "$target" 2>/dev/null)
        if [[ "$current" == "$content" ]]; then
            log_skip "$target уже актуален"
            return 0
        fi
        local answer=""
        safe_read "Файл $target существует. Перезаписать? [y/N]: " "N" answer
        if [[ ! "$answer" =~ ^[YyДд]$ ]]; then
            log_skip "Не перезаписан: $target"
            return 1
        fi
        sudo cp -a "$target" "$target.bak.$(date +%s)" 2>/dev/null
    fi
    sudo mkdir -p "$(dirname "$target")"
    if printf '%s\n' "$content" | sudo tee "$target" > /dev/null; then
        log_success "Записан: $target"
    else
        log_error "Не удалось записать: $target"
        return 1
    fi
}

pkg_in_repo() { pacman -Si "$1" &>/dev/null; }
pkg_installed() { pacman -Qi "$1" &>/dev/null; }

install_pacman_pkgs() {
    local -a pkgs=("$@") to_install=() not_found=()
    for pkg in "${pkgs[@]}"; do
        pkg_installed "$pkg" && continue
        if pkg_in_repo "$pkg"; then
            to_install+=("$pkg")
        else
            not_found+=("$pkg")
            log_warn "Пакет '$pkg' не найден"
        fi
    done
    if [[ ${#to_install[@]} -eq 0 ]]; then
        [[ ${#not_found[@]} -eq 0 ]] && log_skip "Все пакеты установлены"
        [[ ${#not_found[@]} -gt 0 ]] && return 1
        return 0
    fi
    log_info "Устанавливаю: ${to_install[*]}"
    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        [[ ${#not_found[@]} -gt 0 ]] && return 1
        return 0
    else
        log_error "Ошибка установки пакетов"
        return 1
    fi
}

install_aur_pkg() {
    local pkg="$1"
    pkg_installed "$pkg" && { log_skip "$pkg установлен"; return 0; }
    command -v yay &>/dev/null || { log_error "yay нет"; return 1; }
    log_info "AUR: $pkg"
    yay -S --needed --noconfirm "$pkg" && { log_success "$pkg установлен"; return 0; }
    log_warn "Не удалось: $pkg"
    return 1
}

install_smart() {
    local pkg="$1"
    pkg_installed "$pkg" && { log_skip "$pkg установлен"; return 0; }
    if pkg_in_repo "$pkg"; then
        install_pacman_pkgs "$pkg"; return $?
    fi
    install_aur_pkg "$pkg"
}

check_internet() {
    ping -c 1 -W 3 archlinux.org &>/dev/null || { log_error "Нет интернета"; return 1; }
}

detect_gpu() {
    local lspci_output gpus=""
    lspci_output=$(lspci | grep -iE 'vga|3d|display')
    grep -qi nvidia <<< "$lspci_output" && gpus+="nvidia "
    grep -qiE 'amd|radeon|ati' <<< "$lspci_output" && gpus+="amd "
    grep -qi intel <<< "$lspci_output" && gpus+="intel "
    echo "${gpus% }"
}

has_cachyos_repo() { grep -q "^\[cachyos" /etc/pacman.conf 2>/dev/null; }

#==============================================================================
# Preflight
#==============================================================================
preflight_checks() {
    log_header "Предварительные проверки"

    [[ $EUID -eq 0 ]] && { log_error "Не от root!"; exit 1; }
    command -v pacman &>/dev/null || { log_error "Не Arch"; exit 1; }
    sudo -v || { log_error "Нужен sudo"; exit 1; }

    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPER_PID=$!

    check_internet || exit 1

    local free_mb
    free_mb=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$free_mb" && "$free_mb" =~ ^[0-9]+$ && "$free_mb" -lt 5000 ]]; then
        log_warn "Мало места: ${free_mb}MB"
        local a=""; safe_read "Продолжить? [y/N]: " "N" a
        [[ "$a" =~ ^[YyДд]$ ]] || exit 1
    fi

    has_cachyos_repo && log_success "CachyOS репо найден" || \
        log_warn "CachyOS репо НЕ найден"

    log_success "Проверки OK"
}

#==============================================================================
# Интерактивный выбор пользовательских настроек
#==============================================================================
ask_user_preferences() {
    log_header "Пользовательские настройки"

    echo "${BOLD}Переключение языка:${NC}"
    echo "  1) CapsLock         — по нажатию CapsLock (рекомендую)"
    echo "  2) Alt+Shift        — классика Windows"
    echo "  3) Super+Space      — macOS стиль"
    echo "  4) Shift+CapsLock   — CapsLock переключает, Shift+CapsLock = CapsLock"
    echo "  5) Ctrl+Shift"

    local lc=""
    safe_read "Выбор [1-5, по умолчанию 1]: " "1" lc

    case "$lc" in
        2) USER_LANG_SWITCH="grp:alt_shift_toggle" ;;
        3) USER_LANG_SWITCH="grp:win_space_toggle" ;;
        4) USER_LANG_SWITCH="grp:caps_toggle,grp_led:caps" ;;
        5) USER_LANG_SWITCH="grp:ctrl_shift_toggle" ;;
        *) USER_LANG_SWITCH="grp:caps_toggle" ;;
    esac

    log_success "Переключение: $USER_LANG_SWITCH"
}

#==============================================================================
# YAY
#==============================================================================
install_yay() {
    log_header "yay"
    should_run "install_yay" || return 0
    command -v yay &>/dev/null && { log_success "yay есть"; mark_done "install_yay"; return 0; }

    install_pacman_pkgs base-devel git || return 1

    local tmpdir
    tmpdir=$(mktemp -d) || { log_error "mktemp fail"; return 1; }

    if ! git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"; then
        rm -rf "$tmpdir"; log_error "clone fail"; return 1
    fi
    if ! (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm); then
        rm -rf "$tmpdir"; log_error "makepkg fail"; return 1
    fi
    rm -rf "$tmpdir"
    log_success "yay установлен"
    mark_done "install_yay"
}

#==============================================================================
# Обновление
#==============================================================================
update_system() {
    log_header "Обновление системы"
    should_run "update_system" || return 0
    if sudo pacman -Syu --noconfirm; then
        log_success "Обновлено"
        mark_done "update_system"
    else
        log_error "Не обновилось"
        local a=""; safe_read "Продолжить? [y/N]: " "N" a
        [[ "$a" =~ ^[YyДд]$ ]] || return 1
    fi
}

#==============================================================================
# Multilib
#==============================================================================
enable_multilib() {
    log_header "multilib"
    should_run "enable_multilib" || return 0

    if pacman -Sl multilib &>/dev/null; then
        log_skip "multilib уже есть"
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
        if grep -q "^\[multilib\]" /etc/pacman.conf.new; then
            sudo mv /etc/pacman.conf.new /etc/pacman.conf
        else
            sudo rm -f /etc/pacman.conf.new
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | \
                sudo tee -a /etc/pacman.conf > /dev/null
        fi
        sudo pacman -Sy --noconfirm
        log_success "multilib включён"
        mark_done "enable_multilib"
    else
        log_error "Не удалось"
        return 1
    fi
}

#==============================================================================
# GPU — включая NVIDIA автоустановку
#==============================================================================
install_gpu_drivers() {
    log_header "GPU драйверы"
    should_run "install_gpu_drivers" || return 0

    local gpus
    gpus=$(detect_gpu)
    log_info "GPU: ${gpus:-нет}"

    local -a pkgs=(vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-utils)

    for gpu in $gpus; do
        case "$gpu" in
            amd)
                log_info "AMD"
                pkgs+=(vulkan-radeon lib32-vulkan-radeon mesa lib32-mesa
                       libva-mesa-driver lib32-libva-mesa-driver
                       mesa-vdpau lib32-mesa-vdpau)
                ;;
            intel)
                log_info "Intel"
                pkgs+=(vulkan-intel lib32-vulkan-intel mesa lib32-mesa
                       intel-media-driver)
                ;;
            nvidia)
                log_info "NVIDIA обнаружена"
                echo "${BOLD}Драйвер NVIDIA:${NC}"
                echo "  1) nvidia-dkms          — проприетарный (рекомендую)"
                echo "  2) nvidia-open-dkms     — открытый проприетарный"
                echo "  3) nouveau (mesa)       — полностью открытый (слабее)"
                echo "  0) Пропустить"

                local nv=""
                safe_read "Выбор [0-3, по умолчанию 1]: " "1" nv

                case "$nv" in
                    0) log_skip "NVIDIA драйвер" ;;
                    2) pkgs+=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils
                              nvidia-settings egl-wayland) ;;
                    3) pkgs+=(mesa lib32-mesa xf86-video-nouveau) ;;
                    *)
                        pkgs+=(nvidia-dkms nvidia-utils lib32-nvidia-utils
                               nvidia-settings egl-wayland)
                        ;;
                esac

                # Модули для Wayland
                if [[ "$nv" == "1" || "$nv" == "2" ]]; then
                    # Включаем DRM KMS
                    log_info "Настраиваю NVIDIA для Wayland"
                    local nvidia_modprobe='options nvidia_drm modeset=1 fbdev=1'
                    safe_write_root /etc/modprobe.d/nvidia.conf "$nvidia_modprobe"

                    # Модули в initramfs
                    local nvidia_modules='MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)'
                    if [[ -f /etc/mkinitcpio.conf ]]; then
                        if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
                            backup_file /etc/mkinitcpio.conf
                            sudo sed -i "s/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" \
                                /etc/mkinitcpio.conf
                            log_info "NVIDIA модули добавлены в mkinitcpio"
                            log_warn "Нужно выполнить: sudo mkinitcpio -P (после установки драйвера)"
                        fi
                    fi
                fi
                ;;
        esac
    done

    install_pacman_pkgs "${pkgs[@]}"
    mark_done "install_gpu_drivers"
}

#==============================================================================
# Sway
#==============================================================================
install_sway() {
    log_header "Sway и компоненты"
    should_run "install_sway" || return 0

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
    )

    install_pacman_pkgs "${packages[@]}"

    if command -v systemctl &>/dev/null; then
        systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null \
            && log_success "PipeWire OK" || log_warn "PipeWire уже активен"
    fi

    mark_done "install_sway"
}

#==============================================================================
# Файловый менеджер
#==============================================================================
install_file_manager() {
    log_header "Файловый менеджер"
    should_run "install_file_manager" || return 0

    echo "${BOLD}Файловый менеджер:${NC}"
    echo "  1) thunar (рекомендую)"
    echo "  2) pcmanfm"
    echo "  3) nnn (терминал)"
    echo "  4) lf (терминал)"
    echo "  5) thunar + nnn"
    echo "  0) Пропустить"

    local c=""; safe_read "[0-5, по умолчанию 1]: " "1" c
    case "$c" in
        0) log_skip "ФМ" ;;
        2) install_pacman_pkgs pcmanfm-gtk3 gvfs gvfs-mtp ;;
        3) install_pacman_pkgs nnn ;;
        4) install_pacman_pkgs lf ;;
        5) install_pacman_pkgs thunar thunar-volman thunar-archive-plugin gvfs gvfs-mtp tumbler nnn ;;
        *) install_pacman_pkgs thunar thunar-volman thunar-archive-plugin gvfs gvfs-mtp tumbler ;;
    esac
    mark_done "install_file_manager"
}

#==============================================================================
# Игры
#==============================================================================
install_gaming() {
    log_header "Steam и игры"
    should_run "install_gaming" || return 0

    local a=""; safe_read "Steam и игры? [Y/n]: " "Y" a
    if [[ ! "$a" =~ ^[YyДд]$ ]]; then
        log_skip "Игры"; mark_done "install_gaming"; return 0
    fi

    install_pacman_pkgs steam gamemode lib32-gamemode mangohud lib32-mangohud gamescope
    install_smart proton-cachyos
    mark_done "install_gaming"
}

#==============================================================================
# Zen
#==============================================================================
install_zen_browser() {
    log_header "Zen Browser"
    should_run "install_zen_browser" || return 0

    local a=""; safe_read "Zen Browser? [Y/n]: " "Y" a
    if [[ ! "$a" =~ ^[YyДд]$ ]]; then
        log_skip "Zen"; mark_done "install_zen_browser"; return 0
    fi

    for name in zen-browser-bin zen-browser; do
        if pkg_in_repo "$name"; then
            install_pacman_pkgs "$name" && { mark_done "install_zen_browser"; return 0; }
        fi
    done
    install_aur_pkg zen-browser-bin || install_aur_pkg zen-browser || log_warn "Zen не установлен"
    mark_done "install_zen_browser"
}

#==============================================================================
# Тёплая тёмная тема (без синих акцентов)
# Палитра: тёплый серый, кремовый, коричневый
#==============================================================================
setup_themes() {
    log_header "Тёплая тёмная тема"
    should_run "setup_themes" || return 0

    install_pacman_pkgs adw-gtk-theme gnome-themes-extra papirus-icon-theme \
                        qt5ct qt6ct kvantum adwaita-icon-theme

    local gtk_theme="adw-gtk3-dark"

    safe_write ~/.gtkrc-2.0 "gtk-theme-name=\"$gtk_theme\"
gtk-icon-theme-name=\"Adwaita\"
gtk-cursor-theme-name=\"Adwaita\"
gtk-cursor-theme-size=$USER_CURSOR_SIZE
gtk-font-name=\"Sans 11\"
gtk-application-prefer-dark-theme=1"

    safe_write ~/.config/gtk-3.0/settings.ini "[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=$USER_CURSOR_SIZE
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:close"

    safe_write ~/.config/gtk-4.0/settings.ini "[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=$USER_CURSOR_SIZE
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1"

    safe_write ~/.icons/default/index.theme "[Icon Theme]
Inherits=Adwaita"

    log_success "Тёплая тёмная тема"
    mark_done "setup_themes"
}

#==============================================================================
# Экстра
#==============================================================================
install_extras() {
    log_header "Шрифты и утилиты"
    should_run "install_extras" || return 0

    local -a fonts=(ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts noto-fonts-emoji)
    pkg_in_repo noto-fonts-cjk && fonts+=(noto-fonts-cjk)
    pkg_in_repo noto-fonts-cjk-vf && ! pkg_in_repo noto-fonts-cjk && fonts+=(noto-fonts-cjk-vf)

    install_pacman_pkgs "${fonts[@]}" \
        htop btop fastfetch p7zip unrar unzip \
        man-db man-pages bash-completion wget curl rsync

    mark_done "install_extras"
}

#==============================================================================
# Папки
#==============================================================================
create_directories() {
    log_header "Папки"
    should_run "create_directories" || return 0

    for d in ~/Pictures/Screenshots ~/Downloads ~/Documents ~/Videos ~/Music; do
        mkdir -p "$d" && log_success "$d" || log_error "$d"
    done
    mark_done "create_directories"
}

#==============================================================================
# Мышь
#==============================================================================
configure_mouse() {
    log_header "Мышь (без ускорения)"
    should_run "configure_mouse" || return 0

    safe_write_root /etc/X11/xorg.conf.d/30-mouse-noaccel.conf \
'Section "InputClass"
    Identifier "Mouse - no accel"
    MatchIsPointer "yes"
    Driver "libinput"
    Option "AccelProfile" "flat"
    Option "AccelSpeed" "0"
    Option "MiddleEmulation" "off"
EndSection

Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "yes"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection'

    mark_done "configure_mouse"
}

#==============================================================================
# SWAY CONFIG — нормальный тайлинг, тёплая тема, --to-code
#==============================================================================
configure_sway() {
    log_header "Конфигурация Sway"
    should_run "configure_sway" || return 0

    # Палитра: тёплая тёмная ч/б
    # bg:      #1c1b1a  (тёплый чёрный)
    # fg:      #d4cfc9  (тёплый белый/кремовый)
    # accent:  #a89984  (тёплый серо-коричневый)
    # dim:     #504945  (тёмный тёплый серый)
    # urgent:  #cc6666  (приглушённый красный)
    # border:  #3c3836  (границы)

    local sway_config='# SWAY CONFIG v4 — тёплая тёмная тема, нормальный тайлинг
# Все bindsym с --to-code — работают на любой раскладке

set $mod Mod4
set $term foot
set $menu fuzzel

font pango:JetBrains Mono 10

# ── Автозапуск ───────────────────────────────────────────────
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec waybar
exec mako
exec nm-applet --indicator
exec wl-paste --watch cliphist store
exec kanshi

exec swayidle -w \
    timeout 300 "swaylock -f -c 1c1b1a" \
    timeout 600 "swaymsg output * power off" \
    resume "swaymsg output * power on" \
    before-sleep "swaylock -f -c 1c1b1a"

exec_always gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

# ── Внешний вид ──────────────────────────────────────────────
output * bg #1c1b1a solid_color

# ТАЙЛИНГ: без заголовков, только тонкая граница
# title_format НЕ нужен — title bar полностью убран через pixel
default_border pixel 1
default_floating_border pixel 1

# НЕ скрывать границу при одном окне — иначе непонятно фокус
smart_borders off

# Зазоры между окнами
gaps inner 3
gaps outer 0

# Тёплая палитра (border bg text indicator child_border)
client.focused          #a89984 #1c1b1a #d4cfc9 #a89984 #a89984
client.focused_inactive #504945 #1c1b1a #928374 #3c3836 #3c3836
client.unfocused        #3c3836 #1c1b1a #928374 #3c3836 #282726
client.urgent           #cc6666 #1c1b1a #d4cfc9 #cc6666 #cc6666

# ── Тайлинг: нормальное поведение ────────────────────────────
# Новые окна открываются РЯДОМ с текущим (это дефолт sway)
# Направление сплита — горизонтально по умолчанию
# Никаких assign — всё на текущем рабочем столе

# ── Ввод ─────────────────────────────────────────────────────
input type:keyboard {
    xkb_layout us,ru
    xkb_options '"$USER_LANG_SWITCH"'
    repeat_delay 300
    repeat_rate 50
}

input type:pointer {
    accel_profile flat
    pointer_accel 0
    middle_emulation disabled
}

input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    middle_emulation enabled
    accel_profile adaptive
    pointer_accel 0
}

seat seat0 xcursor_theme '"$USER_CURSOR_THEME"' '"$USER_CURSOR_SIZE"'

# ── Клавиши (--to-code = работают на ЛЮБОЙ раскладке) ────────
bindsym --to-code $mod+Return exec $term
bindsym --to-code $mod+d exec $menu
bindsym --to-code $mod+q kill
bindsym --to-code $mod+Shift+c reload
bindsym --to-code $mod+Shift+e exec swaynag -t warning -m "Выйти?" -B "Да" "swaymsg exit"

bindsym --to-code $mod+Escape exec swaylock -f -c 1c1b1a

# Скриншоты
bindsym Print exec sh -c '\''grim ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png'\''
bindsym --to-code $mod+Print exec sh -c '\''grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png'\''
bindsym --to-code $mod+Shift+Print exec sh -c '\''grim -g "$(slurp)" - | wl-copy'\''

bindsym --to-code $mod+e exec thunar
bindsym --to-code $mod+b exec zen-browser

# Медиа
bindsym XF86AudioRaiseVolume exec pamixer -i 5
bindsym XF86AudioLowerVolume exec pamixer -d 5
bindsym XF86AudioMute exec pamixer -t
bindsym XF86AudioMicMute exec pamixer --default-source -t
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

# ── Навигация ────────────────────────────────────────────────
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

# ── Разметка ─────────────────────────────────────────────────
bindsym --to-code $mod+v splith
bindsym --to-code $mod+s splitv
bindsym --to-code $mod+w layout tabbed
bindsym --to-code $mod+t layout stacking
bindsym --to-code $mod+n layout toggle split

bindsym --to-code $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym --to-code $mod+a focus parent

# ── Рабочие столы ────────────────────────────────────────────
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

# ── Resize ───────────────────────────────────────────────────
mode "resize" {
    bindsym --to-code h resize shrink width 30px
    bindsym --to-code j resize grow height 30px
    bindsym --to-code k resize shrink height 30px
    bindsym --to-code l resize grow width 30px
    bindsym Left resize shrink width 30px
    bindsym Down resize grow height 30px
    bindsym Up resize shrink height 30px
    bindsym Right resize grow width 30px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym --to-code $mod+r mode "resize"

# ── Правила (floating для диалогов, БЕЗ assign) ─────────────
for_window [app_id="pavucontrol"] floating enable
for_window [app_id="nm-connection-editor"] floating enable
for_window [app_id="blueman-manager"] floating enable
for_window [window_role="pop-up"] floating enable
for_window [window_role="dialog"] floating enable
for_window [window_type="dialog"] floating enable

xwayland enable'

    # Проверка синтаксиса
    if command -v sway &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        printf '%s\n' "$sway_config" > "$tmp"
        if sway -C -c "$tmp" &>/dev/null; then
            log_success "Синтаксис sway OK"
        else
            log_warn "Синтаксис sway — проверь вручную"
        fi
        rm -f "$tmp"
    fi

    safe_write ~/.config/sway/config "$sway_config"

    # ── WAYBAR (тёплая тема, без лишней строки окон) ──────────

    local waybar_config='{
    "layer": "top",
    "position": "top",
    "height": 28,
    "spacing": 4,
    "modules-left": ["sway/workspaces", "sway/mode"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "idle_inhibitor", "pulseaudio", "network", "cpu", "memory", "temperature", "battery", "sway/language"],

    "sway/workspaces": {
        "disable-scroll": false,
        "all-outputs": true,
        "format": "{name}"
    },
    "sway/mode": { "format": "{}" },
    "sway/language": {
        "format": "{}",
        "on-click": "swaymsg input type:keyboard xkb_switch_layout next"
    },
    "clock": {
        "format": "{:%H:%M  %a %d.%m}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": { "format": "cpu {usage}%", "interval": 2 },
    "memory": { "format": "mem {}%", "interval": 5 },
    "temperature": {
        "critical-threshold": 80,
        "format": "{temperatureC}°"
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "bat {capacity}%",
        "format-charging": "chr {capacity}%"
    },
    "network": {
        "format-wifi": "net {signalStrength}%",
        "format-ethernet": "eth",
        "format-disconnected": "off",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "nm-connection-editor"
    },
    "pulseaudio": {
        "format": "vol {volume}%",
        "format-muted": "mute",
        "on-click": "pamixer -t",
        "on-click-right": "pavucontrol"
    },
    "idle_inhibitor": {
        "format": "{icon}",
        "format-icons": { "activated": "caffeine", "deactivated": "" }
    },
    "tray": { "spacing": 6 }
}'
    safe_write ~/.config/waybar/config.jsonc "$waybar_config"
    ln -sf config.jsonc ~/.config/waybar/config 2>/dev/null

    # Стиль waybar — тёплая ч/б
    local waybar_style='* {
    font-family: "JetBrains Mono";
    font-size: 12px;
    min-height: 0;
}
window#waybar {
    background-color: rgba(28, 27, 26, 0.95);
    color: #d4cfc9;
    border-bottom: 1px solid #3c3836;
}
#workspaces button {
    padding: 0 6px;
    color: #928374;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
}
#workspaces button:hover { background: rgba(168, 153, 132, 0.15); }
#workspaces button.focused {
    color: #d4cfc9;
    border-bottom: 2px solid #a89984;
}
#workspaces button.urgent {
    color: #cc6666;
    border-bottom: 2px solid #cc6666;
}
#clock, #battery, #cpu, #memory, #temperature,
#network, #pulseaudio, #tray, #mode, #idle_inhibitor,
#language {
    padding: 0 8px;
    color: #d4cfc9;
}
#battery.warning { color: #d79921; }
#battery.critical:not(.charging) {
    color: #cc6666;
    animation: blink 0.5s linear infinite alternate;
}
#temperature.critical { color: #cc6666; }
#network.disconnected { color: #928374; }
#pulseaudio.muted { color: #928374; }
#idle_inhibitor.activated { color: #d79921; }
@keyframes blink { to { color: #1c1b1a; } }'
    safe_write ~/.config/waybar/style.css "$waybar_style"

    # ── FOOT (тёплая тема) ────────────────────────────────────
    local foot_config='[main]
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
# Тёплая тёмная ч/б
background=1c1b1a
foreground=d4cfc9

# Обычные цвета (тёплые)
regular0=282726
regular1=cc6666
regular2=a9b665
regular3=d79921
regular4=a89984
regular5=b16286
regular6=89b482
regular7=d4cfc9

# Яркие
bright0=504945
bright1=cc6666
bright2=a9b665
bright3=d79921
bright4=a89984
bright5=b16286
bright6=89b482
bright7=ebdbb2

selection-foreground=d4cfc9
selection-background=504945'
    safe_write ~/.config/foot/foot.ini "$foot_config"

    # ── FUZZEL (тёплая) ───────────────────────────────────────
    local fuzzel_config='[main]
font=JetBrains Mono:size=12
terminal=foot
layer=overlay
prompt="> "
width=45
lines=12

[colors]
background=1c1b1aee
text=d4cfc9ff
match=d79921ff
selection=504945ff
selection-text=ebdbb2ff
border=a89984ff

[border]
width=1
radius=0

[key-bindings]
cancel=Escape Control+c'
    safe_write ~/.config/fuzzel/fuzzel.ini "$fuzzel_config"

    # ── MAKO (тёплая) ────────────────────────────────────────
    local mako_config='sort=-time
layer=overlay
anchor=top-right
width=320
height=120
margin=8
padding=12
border-size=1
border-radius=0
border-color=#a89984
background-color=#1c1b1aee
text-color=#d4cfc9
default-timeout=5000
font=JetBrains Mono 11

[urgency=high]
border-color=#cc6666
default-timeout=10000

[urgency=low]
border-color=#504945
default-timeout=3000'
    safe_write ~/.config/mako/config "$mako_config"

    mark_done "configure_sway"
}

#==============================================================================
# Env
#==============================================================================
setup_environment() {
    log_header "Переменные окружения"
    should_run "setup_environment" || return 0

    # Определяем NVIDIA-специфичные переменные
    local nvidia_vars=""
    if lspci | grep -qi nvidia; then
        nvidia_vars='
# NVIDIA Wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
LIBVA_DRIVER_NAME=nvidia'
    fi

    local env_config="XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=sway
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
QT_AUTO_SCREEN_SCALE_FACTOR=1
MOZ_ENABLE_WAYLAND=1
MOZ_DBUS_REMOTE=1
ELECTRON_OZONE_PLATFORM_HINT=auto
XCURSOR_THEME=$USER_CURSOR_THEME
XCURSOR_SIZE=$USER_CURSOR_SIZE
_JAVA_AWT_WM_NONREPARENTING=1${nvidia_vars}"

    safe_write ~/.config/environment.d/sway.conf "$env_config"

    local autostart_marker="# SWAY_AUTOSTART_MANAGED_BY_SETUP"
    if [[ -f ~/.bash_profile ]] && grep -qF "$autostart_marker" ~/.bash_profile; then
        log_skip "Автозапуск уже есть"
    else
        backup_file ~/.bash_profile
        # Используем переменные сразу, не heredoc с кавычками
        cat >> ~/.bash_profile << SWAY_EOF

$autostart_marker
if [ -z "\$WAYLAND_DISPLAY" ] && [ -z "\$DISPLAY" ] && [ "\${XDG_VTNR:-0}" -eq 1 ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=sway
    export QT_QPA_PLATFORM=wayland
    export QT_QPA_PLATFORMTHEME=qt5ct
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export MOZ_ENABLE_WAYLAND=1
    export MOZ_DBUS_REMOTE=1
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export XCURSOR_THEME=$USER_CURSOR_THEME
    export XCURSOR_SIZE=$USER_CURSOR_SIZE
    export _JAVA_AWT_WM_NONREPARENTING=1${nvidia_vars:+
$(echo "$nvidia_vars" | sed 's/^/    export /' | sed '/^[[:space:]]*$/d' | sed 's/^    export # .*//')}
    exec sway
fi
SWAY_EOF
        log_success "Автозапуск Sway добавлен"
    fi

    mark_done "setup_environment"
}

#==============================================================================
# Отчёт
#==============================================================================
print_summary() {
    log_header "ИТОГИ"

    echo "${BOLD}Статистика:${NC}"
    echo "  ${RED}Ошибок:${NC}         $ERRORS"
    echo "  ${YELLOW}Предупреждений:${NC} $WARNINGS"
    echo "  ${BLUE}Пропущено:${NC}      $SKIPPED"
    echo ""
    echo "${BOLD}Лог:${NC}    $LOG_FILE"
    echo "${BOLD}Бэкапы:${NC} $BACKUP_DIR"
    echo ""

    if [[ $ERRORS -eq 0 ]]; then
        echo "${GREEN}${BOLD}Готово!${NC}"
    else
        echo "${YELLOW}${BOLD}Есть ошибки — проверь лог.${NC}"
    fi

    echo ""
    echo "${BOLD}Мышь:${NC} без ускорения (flat), курсор Adwaita ${USER_CURSOR_SIZE}px"
    echo "${BOLD}Язык:${NC} $USER_LANG_SWITCH"
    echo ""
    echo "${BOLD}Клавиши:${NC}"
    echo "  Super+Enter  — терминал"
    echo "  Super+D      — лаунчер"
    echo "  Super+Q      — закрыть"
    echo "  Super+Escape — блокировка"
    echo "  Super+B/E    — браузер/файлы"
    echo "  Super+H/J/K/L — навигация"
    echo "  Super+V/S    — сплит гориз/верт"
    echo "  Super+F      — фуллскрин"
    echo "  Super+1..0   — рабочие столы"
    echo "  Super+R      — режим ресайза"
    echo ""
    echo "${BOLD}Тайлинг:${NC} окна открываются рядом на текущем столе"
    echo "${BOLD}Перезагрузись для применения всех настроек.${NC}"
}

#==============================================================================
# MAIN
#==============================================================================
main() {
    clear
    echo "${BOLD}${CYAN}"
    cat << BANNER
   ╔═══════════════════════════════════════════════╗
   ║      CachyOS Sway Setup v${SCRIPT_VERSION}                  ║
   ║      Тёплая тёмная тема • Нормальный тайлинг  ║
   ╚═══════════════════════════════════════════════╝
BANNER
    echo "${NC}"

    echo "${BOLD}Лог:${NC}     $LOG_FILE"
    echo "${BOLD}Бэкапы:${NC}  $BACKUP_DIR"
    echo ""
    echo "${YELLOW}Можно перезапускать — шаги пропускаются.${NC}"
    echo ""

    local c=""; safe_read "Продолжить? [Y/n]: " "Y" c
    [[ "$c" =~ ^[YyДд]$ ]] || { log_warn "Отмена"; exit 0; }

    preflight_checks
    ask_user_preferences

    install_yay              || true
    update_system            || true
    enable_multilib          || true
    install_gpu_drivers      || true
    install_sway             || true
    install_file_manager     || true
    install_gaming           || true
    install_zen_browser      || true
    setup_themes             || true
    install_extras           || true
    create_directories       || true
    configure_mouse          || true
    configure_sway           || true
    setup_environment        || true

    print_summary

    local r=""; safe_read "Перезагрузить? [y/N]: " "N" r
    [[ "$r" =~ ^[YyДд]$ ]] && sudo reboot
}

main "$@"
