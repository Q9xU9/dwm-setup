#!/bin/bash

#==============================================================================
# CachyOS Post-Install Setup Script v3
# Приоритеты: надёжность → производительность → практичность → красота
# Изменения v3:
#   - Приоритет pacman над AUR (zen-browser, proton-cachyos и др. из репо)
#   - Исправлен multilib (раскомментирование вместо дублирования)
#   - Исправлен environment.d (переменные экспортируются в .bash_profile)
#   - Полноценная система состояний для всех шагов
#   - Убраны ANSI-коды из лог-файла
#   - Безопасный trap RETURN, обработка SIGINT
#   - Проверка синтаксиса sway config перед записью
#   - Точный подсчёт ошибок/предупреждений
#==============================================================================

set -o pipefail

readonly SCRIPT_VERSION="3.0"
readonly LOG_DIR="$HOME/.cache/cachyos-setup"
readonly LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="$LOG_DIR/backups/$(date +%Y%m%d-%H%M%S)"
readonly STATE_FILE="$LOG_DIR/state"

ERRORS=0
WARNINGS=0
SKIPPED=0

# Цвета только для терминала
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

#==============================================================================
# Инициализация логирования (без ANSI в файле)
#==============================================================================
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$STATE_FILE"

# Пишем в stdout как обычно, а в файл без цветов
strip_ansi() {
    sed -u 's/\x1b\[[0-9;]*m//g'
}

# Дублируем stdout/stderr в файл, вырезая ANSI из файла
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

#==============================================================================
# Обработка сигналов
#==============================================================================
SUDO_KEEPER_PID=""
cleanup_on_exit() {
    local exit_code=$?
    [[ -n "$SUDO_KEEPER_PID" ]] && kill "$SUDO_KEEPER_PID" 2>/dev/null
    exit "$exit_code"
}
handle_interrupt() {
    echo ""
    log_warn "Прерывание пользователем (Ctrl+C)"
    cleanup_on_exit
}
trap cleanup_on_exit EXIT
trap handle_interrupt INT TERM

#==============================================================================
# Утилиты
#==============================================================================

safe_read() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input=""
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

# Единый механизм пропуска для всех шагов
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
        if cp -a "$file" "$target" 2>/dev/null; then
            log_info "Бэкап: $file"
        fi
    fi
}

safe_write() {
    local target="$1"
    local content="$2"

    if [[ -f "$target" ]]; then
        local current
        current=$(cat "$target" 2>/dev/null)
        if [[ "$current" == "$content" ]]; then
            log_skip "Конфиг $target уже актуален"
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
    # printf с явным \n в конце
    if printf '%s\n' "$content" > "$target"; then
        log_success "Записан: $target"
        return 0
    else
        log_error "Не удалось записать: $target"
        return 1
    fi
}

pkg_in_repo() {
    pacman -Si "$1" &>/dev/null
}

pkg_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Установка пакетов — возвращает 0 только если ВСЕ нужные установлены
install_pacman_pkgs() {
    local -a pkgs=("$@")
    local -a to_install=()
    local -a not_found=()

    for pkg in "${pkgs[@]}"; do
        if pkg_installed "$pkg"; then
            continue
        fi
        if pkg_in_repo "$pkg"; then
            to_install+=("$pkg")
        else
            not_found+=("$pkg")
            log_warn "Пакет '$pkg' не найден в репозиториях"
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        if [[ ${#not_found[@]} -eq 0 ]]; then
            log_skip "Все пакеты уже установлены"
        fi
        [[ ${#not_found[@]} -gt 0 ]] && return 1
        return 0
    fi

    log_info "Устанавливаю: ${to_install[*]}"
    if sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        [[ ${#not_found[@]} -gt 0 ]] && return 1
        return 0
    else
        log_error "Ошибка при установке пакетов"
        return 1
    fi
}

install_aur_pkg() {
    local pkg="$1"

    if pkg_installed "$pkg"; then
        log_skip "$pkg уже установлен"
        return 0
    fi

    if ! command -v yay &>/dev/null; then
        log_error "yay не установлен, не могу поставить $pkg"
        return 1
    fi

    log_info "Устанавливаю AUR: $pkg"
    if yay -S --needed --noconfirm "$pkg"; then
        log_success "$pkg установлен"
        return 0
    else
        log_warn "Не удалось установить $pkg из AUR"
        return 1
    fi
}

# Умная установка: сначала pacman (включая CachyOS репо), потом AUR
install_smart() {
    local pkg="$1"
    if pkg_installed "$pkg"; then
        log_skip "$pkg уже установлен"
        return 0
    fi
    if pkg_in_repo "$pkg"; then
        log_info "$pkg найден в репозитории, ставлю через pacman"
        install_pacman_pkgs "$pkg"
        return $?
    fi
    log_info "$pkg отсутствует в репо, пробую AUR"
    install_aur_pkg "$pkg"
}

check_internet() {
    if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_error "Нет интернета"
        return 1
    fi
    return 0
}

detect_gpu() {
    local lspci_output
    lspci_output=$(lspci | grep -iE 'vga|3d|display')
    local gpus=""
    grep -qi nvidia <<< "$lspci_output" && gpus+="nvidia "
    grep -qiE 'amd|radeon|ati' <<< "$lspci_output" && gpus+="amd "
    grep -qi intel <<< "$lspci_output" && gpus+="intel "
    echo "${gpus% }"
}

# Проверка что репозиторий CachyOS подключён
has_cachyos_repo() {
    grep -q "^\[cachyos" /etc/pacman.conf 2>/dev/null
}

#==============================================================================
# Preflight
#==============================================================================
preflight_checks() {
    log_header "Предварительные проверки"

    if [[ $EUID -eq 0 ]]; then
        log_error "Не запускай от root!"
        exit 1
    fi

    if ! command -v pacman &>/dev/null; then
        log_error "pacman не найден"
        exit 1
    fi

    if ! sudo -v; then
        log_error "Нужны sudo права"
        exit 1
    fi

    # Sudo keeper
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPER_PID=$!

    check_internet || exit 1

    local free_mb
    free_mb=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$free_mb" && "$free_mb" =~ ^[0-9]+$ ]] && [[ "$free_mb" -lt 5000 ]]; then
        log_warn "Мало места: ${free_mb}MB"
        local answer=""
        safe_read "Продолжить? [y/N]: " "N" answer
        [[ "$answer" =~ ^[YyДд]$ ]] || exit 1
    fi

    if has_cachyos_repo; then
        log_success "Репозиторий CachyOS обнаружен"
    else
        log_warn "Репозиторий CachyOS НЕ обнаружен — многие пакеты будут ставиться из AUR"
    fi

    log_success "Проверки пройдены"
}

#==============================================================================
# YAY
#==============================================================================
install_yay() {
    log_header "Установка yay"
    should_run "install_yay" || return 0

    if command -v yay &>/dev/null; then
        log_success "yay уже установлен"
        mark_done "install_yay"
        return 0
    fi

    install_pacman_pkgs base-devel git || return 1

    local tmpdir
    tmpdir=$(mktemp -d) || { log_error "mktemp failed"; return 1; }

    local yay_cleanup="rm -rf \"$tmpdir\""
    trap "$yay_cleanup" RETURN

    if ! git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"; then
        log_error "git clone yay-bin failed"
        trap - RETURN
        eval "$yay_cleanup"
        return 1
    fi

    if ! (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm); then
        log_error "makepkg yay failed"
        trap - RETURN
        eval "$yay_cleanup"
        return 1
    fi

    trap - RETURN
    eval "$yay_cleanup"

    log_success "yay установлен"
    mark_done "install_yay"
}

#==============================================================================
# Обновление системы
#==============================================================================
update_system() {
    log_header "Обновление системы"
    should_run "update_system" || return 0

    if sudo pacman -Syu --noconfirm; then
        log_success "Система обновлена"
        mark_done "update_system"
        return 0
    fi
    log_error "Не удалось обновить систему"
    local answer=""
    safe_read "Продолжить без обновления? [y/N]: " "N" answer
    [[ "$answer" =~ ^[YyДд]$ ]] || return 1
    return 0
}

#==============================================================================
# Multilib — правильное раскомментирование
#==============================================================================
enable_multilib() {
    log_header "Включение multilib"
    should_run "enable_multilib" || return 0

    # Проверяем активность multilib
    if pacman -Sl multilib &>/dev/null; then
        log_skip "multilib уже активен"
        mark_done "enable_multilib"
        return 0
    fi

    backup_file /etc/pacman.conf

    # Раскомментируем существующий блок [multilib] и Include
    # Используем python-подобный подход через awk для надёжности
    if sudo awk '
        /^#\[multilib\]/ {
            print substr($0, 2)
            getline
            if ($0 ~ /^#Include/) {
                print substr($0, 2)
                next
            }
            print
            next
        }
        { print }
    ' /etc/pacman.conf | sudo tee /etc/pacman.conf.new > /dev/null; then

        # Проверяем что раскомментирование сработало
        if grep -q "^\[multilib\]" /etc/pacman.conf.new; then
            sudo mv /etc/pacman.conf.new /etc/pacman.conf
            log_success "multilib раскомментирован"
        else
            # Fallback: если закомментированного блока не было — дописываем
            sudo rm -f /etc/pacman.conf.new
            log_info "Закомментированный [multilib] не найден, дописываю"
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | \
                sudo tee -a /etc/pacman.conf > /dev/null
        fi

        sudo pacman -Sy --noconfirm
        log_success "multilib включён"
        mark_done "enable_multilib"
        return 0
    else
        log_error "Не удалось изменить pacman.conf"
        return 1
    fi
}

#==============================================================================
# GPU
#==============================================================================
install_gpu_drivers() {
    log_header "GPU драйверы"
    should_run "install_gpu_drivers" || return 0

    local gpus
    gpus=$(detect_gpu)
    log_info "Обнаружены GPU: ${gpus:-нет}"

    local -a pkgs=(vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-utils)

    for gpu in $gpus; do
        case "$gpu" in
            amd)
                log_info "AMD драйверы"
                pkgs+=(vulkan-radeon lib32-vulkan-radeon mesa lib32-mesa
                       libva-mesa-driver lib32-libva-mesa-driver
                       mesa-vdpau lib32-mesa-vdpau)
                ;;
            intel)
                log_info "Intel драйверы"
                pkgs+=(vulkan-intel lib32-vulkan-intel mesa lib32-mesa
                       intel-media-driver)
                ;;
            nvidia)
                log_warn "NVIDIA обнаружена — драйвер ставится вручную!"
                log_warn "  Открытый:        sudo pacman -S nvidia-open-dkms"
                log_warn "  Проприетарный:   sudo pacman -S nvidia-dkms"
                log_warn "  Для Wayland рекомендую 555+ (проприетарный)"
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
    )

    install_pacman_pkgs "${packages[@]}"

    if command -v systemctl &>/dev/null; then
        if systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null; then
            log_success "PipeWire сервисы включены"
        else
            log_warn "PipeWire уже активен или не удалось включить"
        fi
    fi

    mark_done "install_sway"
}

#==============================================================================
# Файловый менеджер
#==============================================================================
install_file_manager() {
    log_header "Файловый менеджер"
    should_run "install_file_manager" || return 0

    echo "${BOLD}Выбери файловый менеджер:${NC}"
    echo "  1) thunar     — GUI (рекомендую)"
    echo "  2) pcmanfm    — легче"
    echo "  3) nnn        — терминальный"
    echo "  4) lf         — терминальный (Go)"
    echo "  5) thunar + nnn"
    echo "  0) Пропустить"

    local fm_choice=""
    safe_read "Выбор [0-5, по умолчанию 1]: " "1" fm_choice

    case "$fm_choice" in
        0) log_skip "Файловый менеджер" ;;
        2) install_pacman_pkgs pcmanfm-gtk3 gvfs gvfs-mtp ;;
        3) install_pacman_pkgs nnn ;;
        4) install_pacman_pkgs lf ;;
        5) install_pacman_pkgs thunar thunar-volman thunar-archive-plugin gvfs gvfs-mtp tumbler nnn ;;
        *) install_pacman_pkgs thunar thunar-volman thunar-archive-plugin gvfs gvfs-mtp tumbler ;;
    esac

    mark_done "install_file_manager"
}

#==============================================================================
# Steam и игры (proton-cachyos из pacman если есть)
#==============================================================================
install_gaming() {
    log_header "Steam и игровые пакеты"
    should_run "install_gaming" || return 0

    local answer=""
    safe_read "Установить Steam и игровые пакеты? [Y/n]: " "Y" answer
    if [[ ! "$answer" =~ ^[YyДд]$ ]]; then
        log_skip "Игровые пакеты"
        mark_done "install_gaming"
        return 0
    fi

    install_pacman_pkgs steam gamemode lib32-gamemode mangohud lib32-mangohud \
                       gamescope

    # proton-cachyos приоритетно из pacman
    install_smart proton-cachyos

    mark_done "install_gaming"
}

#==============================================================================
# Zen Browser — приоритет pacman
#==============================================================================
install_zen_browser() {
    log_header "Zen Browser"
    should_run "install_zen_browser" || return 0

    local answer=""
    safe_read "Установить Zen Browser? [Y/n]: " "Y" answer
    if [[ ! "$answer" =~ ^[YyДд]$ ]]; then
        log_skip "Zen Browser"
        mark_done "install_zen_browser"
        return 0
    fi

    # Пробуем разные имена в pacman (в CachyOS репо часто есть zen-browser-bin)
    local -a pacman_names=(zen-browser-bin zen-browser)
    for name in "${pacman_names[@]}"; do
        if pkg_in_repo "$name"; then
            log_info "Найден в pacman: $name"
            install_pacman_pkgs "$name" && { mark_done "install_zen_browser"; return 0; }
        fi
    done

    # Fallback на AUR
    log_info "В репозиториях не найден, пробую AUR"
    install_aur_pkg zen-browser-bin || install_aur_pkg zen-browser || \
        log_warn "Zen Browser не установлен"

    mark_done "install_zen_browser"
}

#==============================================================================
# Темы
#==============================================================================
setup_themes() {
    log_header "Настройка тем"
    should_run "setup_themes" || return 0

    install_pacman_pkgs adw-gtk-theme gnome-themes-extra papirus-icon-theme \
                        breeze qt5ct qt6ct kvantum

    echo "${BOLD}GTK тема:${NC}"
    echo "  1) adw-gtk3-dark   (рекомендую)"
    echo "  2) Breeze-Dark"
    echo "  3) Materia-dark    (AUR)"
    echo "  4) Arc-Dark"
    echo "  0) Пропустить"

    local theme_choice=""
    safe_read "Выбор [0-4, по умолчанию 1]: " "1" theme_choice

    local gtk_theme=""
    case "$theme_choice" in
        0) log_skip "Тема"; mark_done "setup_themes"; return 0 ;;
        1) gtk_theme="adw-gtk3-dark" ;;
        2) install_pacman_pkgs breeze-gtk && gtk_theme="Breeze-Dark" ;;
        3) install_smart materia-gtk-theme && gtk_theme="Materia-dark" ;;
        4) install_pacman_pkgs arc-gtk-theme && gtk_theme="Arc-Dark" ;;
        *) gtk_theme="adw-gtk3-dark" ;;
    esac

    # Курсоры: пробуем несколько вариантов имени
    if ! pkg_installed breeze; then
        install_pacman_pkgs breeze 2>/dev/null || log_warn "Курсоры Breeze не установлены"
    fi

    safe_write ~/.gtkrc-2.0 "gtk-theme-name=\"$gtk_theme\"
gtk-icon-theme-name=\"Papirus-Dark\"
gtk-cursor-theme-name=\"Breeze_Snow\"
gtk-cursor-theme-size=24
gtk-font-name=\"Sans 11\"
gtk-application-prefer-dark-theme=1"

    safe_write ~/.config/gtk-3.0/settings.ini "[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=:close"

    safe_write ~/.config/gtk-4.0/settings.ini "[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Breeze_Snow
gtk-cursor-theme-size=24
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1"

    safe_write ~/.icons/default/index.theme "[Icon Theme]
Inherits=Breeze_Snow"

    log_success "Тема $gtk_theme настроена"
    mark_done "setup_themes"
}

#==============================================================================
# Шрифты и утилиты
#==============================================================================
install_extras() {
    log_header "Шрифты и утилиты"
    should_run "install_extras" || return 0

    # noto-fonts-cjk актуальное имя, если нет — попробуем vf версию
    local -a fonts=(
        ttf-jetbrains-mono-nerd ttf-font-awesome
        noto-fonts noto-fonts-emoji
    )
    if pkg_in_repo noto-fonts-cjk; then
        fonts+=(noto-fonts-cjk)
    elif pkg_in_repo noto-fonts-cjk-vf; then
        fonts+=(noto-fonts-cjk-vf)
    fi

    install_pacman_pkgs "${fonts[@]}" \
        htop btop fastfetch \
        p7zip unrar unzip \
        man-db man-pages \
        bash-completion \
        wget curl rsync

    mark_done "install_extras"
}

#==============================================================================
# Папки
#==============================================================================
create_directories() {
    log_header "Пользовательские папки"
    should_run "create_directories" || return 0

    local -a dirs=(
        ~/Pictures/Screenshots
        ~/Downloads ~/Documents ~/Videos ~/Music
    )

    for d in "${dirs[@]}"; do
        if mkdir -p "$d"; then
            log_success "Создана: $d"
        else
            log_error "Не удалось: $d"
        fi
    done

    mark_done "create_directories"
}

#==============================================================================
# Sway config
#==============================================================================
configure_sway() {
    log_header "Конфигурация Sway"
    should_run "configure_sway" || return 0

    # Используем одинарные кавычки: $(date), $(slurp) НЕ раскрываются при записи
    local sway_config='# ╔══════════════════════════════════════════════════════════════╗
# ║                    SWAY CONFIG                               ║
# ╚══════════════════════════════════════════════════════════════╝

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
    timeout 300 "swaylock -f -c 1a1b26" \
    timeout 600 "swaymsg output * power off" \
    resume "swaymsg output * power on" \
    before-sleep "swaylock -f -c 1a1b26"

exec_always gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

# ── Внешний вид ──────────────────────────────────────────────
output * bg #1a1b26 solid_color

default_border pixel 2
default_floating_border pixel 2
smart_borders on
smart_gaps on
gaps inner 4
gaps outer 2

# Tokyo Night
client.focused          #7aa2f7 #1a1b26 #c0caf5 #7dcfff   #7aa2f7
client.focused_inactive #414868 #1a1b26 #565f89 #414868   #414868
client.unfocused        #292e42 #1a1b26 #565f89 #292e42   #292e42
client.urgent           #f7768e #1a1b26 #c0caf5 #f7768e   #f7768e

# ── Ввод ─────────────────────────────────────────────────────
input type:keyboard {
    xkb_layout us,ru
    xkb_options grp:alt_shift_toggle,caps:escape
    repeat_delay 300
    repeat_rate 50
}

input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    middle_emulation enabled
}

seat seat0 xcursor_theme Breeze_Snow 24

# ── Клавиши ──────────────────────────────────────────────────
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec swaynag -t warning -m "Выйти из Sway?" -B "Да" "swaymsg exit"

bindsym $mod+Escape exec swaylock -f -c 1a1b26

# Скриншоты (используем оболочку для date/slurp во время нажатия)
bindsym Print exec sh -c "grim ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
bindsym $mod+Print exec sh -c "grim -g \"$(slurp)\" ~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
bindsym $mod+Shift+Print exec sh -c "grim -g \"$(slurp)\" - | wl-copy"

bindsym $mod+e exec thunar
bindsym $mod+b exec zen-browser

bindsym XF86AudioRaiseVolume exec pamixer -i 5
bindsym XF86AudioLowerVolume exec pamixer -d 5
bindsym XF86AudioMute exec pamixer -t
bindsym XF86AudioMicMute exec pamixer --default-source -t
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

# ── Навигация (vim) ──────────────────────────────────────────
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# ── Разметка ─────────────────────────────────────────────────
bindsym $mod+v splith
bindsym $mod+s splitv
bindsym $mod+w layout tabbed
bindsym $mod+t layout stacking
bindsym $mod+n layout toggle split

bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

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
    bindsym h resize shrink width 30px
    bindsym j resize grow height 30px
    bindsym k resize shrink height 30px
    bindsym l resize grow width 30px
    bindsym Left resize shrink width 30px
    bindsym Down resize grow height 30px
    bindsym Up resize shrink height 30px
    bindsym Right resize grow width 30px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# ── Правила окон ─────────────────────────────────────────────
for_window [app_id="pavucontrol"] floating enable
for_window [app_id="nm-connection-editor"] floating enable
for_window [app_id="blueman-manager"] floating enable
for_window [class="Steam" title="Friends List"] floating enable
for_window [class="Steam" title="Steam Settings"] floating enable
assign [class="Steam"] workspace number 9

xwayland enable'

    # Проверка синтаксиса перед записью (если sway уже установлен)
    if command -v sway &>/dev/null; then
        local tmp_config
        tmp_config=$(mktemp)
        printf '%s\n' "$sway_config" > "$tmp_config"
        if sway -C -c "$tmp_config" &>/dev/null; then
            log_success "Sway config: синтаксис OK"
        else
            log_warn "Sway config: проверка синтаксиса не пройдена (записываю всё равно)"
        fi
        rm -f "$tmp_config"
    fi

    safe_write ~/.config/sway/config "$sway_config"

    local waybar_config='{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["sway/workspaces", "sway/mode", "sway/window"],
    "modules-center": ["clock"],
    "modules-right": ["tray", "idle_inhibitor", "pulseaudio", "network", "cpu", "memory", "temperature", "battery"],

    "sway/workspaces": {
        "disable-scroll": false,
        "all-outputs": true,
        "format": "{name}"
    },
    "sway/mode": { "format": "<span style=\"italic\">{}</span>" },
    "sway/window": { "max-length": 50 },
    "clock": {
        "format": "{:%H:%M  %a %d.%m}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": { "format": " {usage}%", "interval": 2 },
    "memory": { "format": " {}%", "interval": 5 },
    "temperature": {
        "critical-threshold": 80,
        "format": " {temperatureC}°C"
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{icon} {capacity}%",
        "format-charging": "⚡ {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    "network": {
        "format-wifi": "  {signalStrength}%",
        "format-ethernet": "󰈀 {ipaddr}",
        "format-disconnected": "⚠ Off",
        "tooltip-format": "{ifname}: {ipaddr}",
        "on-click": "nm-connection-editor"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰝟 mute",
        "format-icons": { "default": ["", "", ""] },
        "on-click": "pamixer -t",
        "on-click-right": "pavucontrol"
    },
    "idle_inhibitor": {
        "format": "{icon}",
        "format-icons": { "activated": "󰅶", "deactivated": "󰛊" }
    },
    "tray": { "spacing": 8 }
}'
    safe_write ~/.config/waybar/config.jsonc "$waybar_config"
    # Waybar в разных версиях ищет разные имена — делаем симлинк
    ln -sf config.jsonc ~/.config/waybar/config 2>/dev/null

    local waybar_style='* {
    font-family: "JetBrains Mono", "Font Awesome 6 Free";
    font-size: 13px;
    min-height: 0;
}
window#waybar {
    background-color: rgba(26, 27, 38, 0.95);
    color: #c0caf5;
    border-bottom: 2px solid #292e42;
}
#workspaces button {
    padding: 0 8px;
    color: #565f89;
    background: transparent;
    border-radius: 0;
    border-bottom: 2px solid transparent;
}
#workspaces button:hover { background: rgba(122, 162, 247, 0.2); }
#workspaces button.focused {
    color: #7aa2f7;
    border-bottom: 2px solid #7aa2f7;
}
#workspaces button.urgent {
    color: #f7768e;
    border-bottom: 2px solid #f7768e;
}
#clock, #battery, #cpu, #memory, #temperature,
#network, #pulseaudio, #tray, #mode, #idle_inhibitor {
    padding: 0 10px;
}
#battery.warning { color: #e0af68; }
#battery.critical:not(.charging) {
    color: #f7768e;
    animation: blink 0.5s linear infinite alternate;
}
#temperature.critical { color: #f7768e; }
#cpu { color: #9ece6a; }
#memory { color: #7dcfff; }
#network.disconnected { color: #f7768e; }
#pulseaudio.muted { color: #565f89; }
@keyframes blink { to { color: #1a1b26; } }'
    safe_write ~/.config/waybar/style.css "$waybar_style"

    local foot_config='[main]
font=JetBrains Mono:size=11
dpi-aware=yes
pad=8x8

[scrollback]
lines=10000

[cursor]
style=beam
blink=yes

[mouse]
hide-when-typing=yes

[colors]
background=1a1b26
foreground=c0caf5
regular0=15161e
regular1=f7768e
regular2=9ece6a
regular3=e0af68
regular4=7aa2f7
regular5=bb9af7
regular6=7dcfff
regular7=a9b1d6
bright0=414868
bright1=f7768e
bright2=9ece6a
bright3=e0af68
bright4=7aa2f7
bright5=bb9af7
bright6=7dcfff
bright7=c0caf5
selection-foreground=c0caf5
selection-background=33467c'
    safe_write ~/.config/foot/foot.ini "$foot_config"

    local fuzzel_config='[main]
font=JetBrains Mono:size=12
terminal=foot
layer=overlay
prompt="❯ "
width=45
lines=12

[colors]
background=1a1b26ee
text=c0caf5ff
match=7aa2f7ff
selection=33467cff
selection-text=c0caf5ff
border=7aa2f7ff

[border]
width=2
radius=8

[key-bindings]
cancel=Escape Control+c'
    safe_write ~/.config/fuzzel/fuzzel.ini "$fuzzel_config"

    local mako_config='sort=-time
layer=overlay
anchor=top-right
width=350
height=150
margin=10
padding=15
border-size=2
border-radius=8
border-color=#7aa2f7
background-color=#1a1b26ee
text-color=#c0caf5
default-timeout=5000
font=JetBrains Mono 11

[urgency=high]
border-color=#f7768e
default-timeout=10000

[urgency=low]
border-color=#414868
default-timeout=3000'
    safe_write ~/.config/mako/config "$mako_config"

    mark_done "configure_sway"
}

#==============================================================================
# Переменные окружения — экспортируются В .bash_profile перед exec sway
#==============================================================================
setup_environment() {
    log_header "Переменные окружения и автозапуск"
    should_run "setup_environment" || return 0

    # environment.d — на случай запуска через display manager с systemd
    local env_config='XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=sway
QT_QPA_PLATFORM="wayland;xcb"
QT_QPA_PLATFORMTHEME=qt5ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
QT_AUTO_SCREEN_SCALE_FACTOR=1
MOZ_ENABLE_WAYLAND=1
MOZ_DBUS_REMOTE=1
ELECTRON_OZONE_PLATFORM_HINT=auto
XCURSOR_THEME=Breeze_Snow
XCURSOR_SIZE=24
_JAVA_AWT_WM_NONREPARENTING=1'
    safe_write ~/.config/environment.d/sway.conf "$env_config"

    # ГЛАВНОЕ: переменные экспортируются ПЕРЕД exec sway в .bash_profile
    local autostart_marker="# SWAY_AUTOSTART_MANAGED_BY_SETUP"
    if [[ -f ~/.bash_profile ]] && grep -qF "$autostart_marker" ~/.bash_profile; then
        log_skip "Автозапуск Sway уже настроен"
    else
        backup_file ~/.bash_profile
        cat >> ~/.bash_profile << 'EOF'

# SWAY_AUTOSTART_MANAGED_BY_SETUP
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
    # Экспортируем переменные окружения (environment.d не работает без systemd-user session)
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=sway
    export QT_QPA_PLATFORM="wayland;xcb"
    export QT_QPA_PLATFORMTHEME=qt5ct
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_AUTO_SCREEN_SCALE_FACTOR=1
    export MOZ_ENABLE_WAYLAND=1
    export MOZ_DBUS_REMOTE=1
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export XCURSOR_THEME=Breeze_Snow
    export XCURSOR_SIZE=24
    export _JAVA_AWT_WM_NONREPARENTING=1
    exec sway
fi
EOF
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
        echo "${GREEN}${BOLD}Всё установлено успешно!${NC}"
    else
        echo "${YELLOW}${BOLD}Установка завершена с ошибками. Проверь лог.${NC}"
    fi

    echo ""
    echo "${BOLD}Что дальше:${NC}"
    echo "  1. Перелогинься / перезагрузись"
    echo "  2. На TTY1 Sway запустится автоматически"
    echo "  3. Или вручную: sway"
    echo ""
    echo "${BOLD}Ключевые клавиши:${NC}"
    echo "  Super+Enter       — терминал"
    echo "  Super+D           — лаунчер"
    echo "  Super+Q           — закрыть окно"
    echo "  Super+Escape      — блокировка"
    echo "  Super+B / E       — браузер / файлы"
    echo "  Super+H/J/K/L     — навигация"
    echo "  Super+1..0        — рабочие столы"
    echo "  Alt+Shift         — RU/EN"
    echo "  CapsLock          — Escape"
}

#==============================================================================
# MAIN
#==============================================================================
main() {
    clear
    echo "${BOLD}${CYAN}"
    cat << BANNER
   ╔═══════════════════════════════════════════════╗
   ║      CachyOS Sway Setup Script v${SCRIPT_VERSION}             ║
   ║   Надёжность • Производительность • Стиль     ║
   ╚═══════════════════════════════════════════════╝
BANNER
    echo "${NC}"

    echo "${BOLD}Лог:${NC}     $LOG_FILE"
    echo "${BOLD}Бэкапы:${NC}  $BACKUP_DIR"
    echo ""
    echo "${BOLD}Приоритет установки:${NC} pacman → CachyOS repo → AUR"
    echo ""
    echo "${YELLOW}Скрипт можно перезапускать — выполненные шаги пропускаются.${NC}"
    echo ""

    local confirm=""
    safe_read "Продолжить? [Y/n]: " "Y" confirm
    if [[ ! "$confirm" =~ ^[YyДд]$ ]]; then
        log_warn "Отменено пользователем"
        exit 0
    fi

    preflight_checks

    # Каждый шаг изолирован
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
    configure_sway           || true
    setup_environment        || true

    print_summary

    local reboot_confirm=""
    safe_read "Перезагрузить сейчас? [y/N]: " "N" reboot_confirm
    if [[ "$reboot_confirm" =~ ^[YyДд]$ ]]; then
        sudo reboot
    fi
}

main "$@"
