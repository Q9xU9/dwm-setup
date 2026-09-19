#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch
# Версия 9.0 — Скриншоты, трей, исправление slock и Telegram

set -e

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/echo

# ===================== ЦВЕТА =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info()  { echo -e "${CYAN}[i]${NC} $1"; }

# ===================== ЗАВИСИМОСТИ =====================
install_packages() {
    log "Обновление системы..."
    sudo pacman -Syu --noconfirm

    log "Установка базовых пакетов..."
    sudo pacman -S --needed --noconfirm \
        base-devel git xorg xorg-xinit xorg-xrandr xorg-xsetroot \
        xf86-input-libinput xorg-xinput \
        libx11 libxft libxinerama freetype2 fontconfig \
        picom dunst \
        xclip xdotool xsel \
        pavucontrol alsa-utils \
        noto-fonts noto-fonts-cjk ttf-jetbrains-mono ttf-font-awesome \
        alacritty lf \
        gnome-disk-utility \
        steam \
        wget curl tar gzip unzip htop neofetch \
        feh scrot brightnessctl \
        polkit lxsession \
        networkmanager network-manager-applet \
        blueman \
        stalonetray \
        libnotify \
        openssh bc

    log "Включение NetworkManager..."
    sudo systemctl enable --now NetworkManager 2>/dev/null || true
}

# ===================== YAY =====================
install_yay() {
    if ! command -v yay &>/dev/null; then
        log "Установка yay..."

        if sudo pacman -S --needed --noconfirm yay 2>/dev/null; then
            log "yay установлен из репозиториев CachyOS!"
        else
            warn "Сборка yay-bin из AUR..."
            cd /tmp
            rm -rf yay-bin
            if git clone --depth 1 https://aur.archlinux.org/yay-bin.git 2>/dev/null; then
                cd yay-bin
                makepkg -si --noconfirm
                cd ~
                log "yay-bin установлен!"
            else
                warn "Сборка yay из исходников..."
                cd /tmp
                rm -rf yay
                git clone --depth 1 https://aur.archlinux.org/yay.git
                cd yay
                makepkg -si --noconfirm
                cd ~
                log "yay установлен!"
            fi
        fi
    else
        log "yay уже установлен"
    fi
}

# ===================== AUR ПАКЕТЫ =====================
install_aur_packages() {
    log "Установка AUR пакетов..."

    info "Zen Browser..."
    yay -S --needed --noconfirm zen-browser-bin || \
    yay -S --needed --noconfirm zen-browser || \
    warn "Zen Browser не найден, установите позже вручную."

    info "Telegram..."
    sudo pacman -S --needed --noconfirm telegram-desktop || \
        yay -S --needed --noconfirm telegram-desktop

    info "Proton..."
    yay -S --needed --noconfirm proton-cachyos-bin 2>/dev/null || \
    yay -S --needed --noconfirm proton-cachyos 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Proton не найден, установите через Steam."

    info "xidlehook (автоблокировка)..."
    yay -S --needed --noconfirm xidlehook 2>/dev/null || \
        warn "xidlehook не найден, автоблокировка не будет работать."
}

# ===================== ЗАГРУЗЧИК SUCKLESS =====================
download_tool() {
    local name=$1
    local gitee_url=$2
    local codeberg_url=$3
    local archive_url=$4

    log "Загрузка $name..."
    mkdir -p ~/suckless
    cd ~/suckless
    rm -rf "$name" "${name}.tar.gz"

    info "Gitee..."
    if git clone --depth 1 "$gitee_url" "$name" 2>/dev/null; then
        log "$name загружен с Gitee!"
        return 0
    fi

    warn "Codeberg..."
    if git clone --depth 1 "$codeberg_url" "$name" 2>/dev/null; then
        log "$name загружен с Codeberg!"
        return 0
    fi

    warn "Wayback Machine..."
    if wget --timeout=10 -qO "${name}.tar.gz" "$archive_url" || \
       curl -L --connect-timeout 10 -o "${name}.tar.gz" "$archive_url"; then
        tar -xzf "${name}.tar.gz"
        local extracted_dir
        extracted_dir=$(tar -tf "${name}.tar.gz" | head -1 | cut -f1 -d"/")
        mv "$extracted_dir" "$name"
        rm "${name}.tar.gz"
        log "$name загружен из Архива Интернета!"
        return 0
    fi

    err "Не удалось загрузить $name!"
}

# ===================== СКРИПТ СКРИНШОТОВ =====================
create_screenshot_script() {
    log "Создание скрипта скриншотов..."

    mkdir -p ~/bin
    mkdir -p ~/Pictures/Screenshots

    cat > ~/bin/screenshot << 'SCREENSHOT'
#!/bin/bash
# Скриншот выделенной области с сохранением в ~/Pictures/Screenshots/

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

FILENAME="screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$SCREENSHOT_DIR/$FILENAME"

# Делаем скриншот выделенной области
scrot -s "$FILEPATH" 2>/dev/null

if [ -f "$FILEPATH" ]; then
    # Копируем в буфер обмена
    xclip -selection clipboard -t image/png -i "$FILEPATH" 2>/dev/null

    # Уведомление
    notify-send "Скриншот сохранён" "$FILENAME\nСкопирован в буфер обмена" \
        -i "$FILEPATH" -t 3000 2>/dev/null
fi
SCREENSHOT

    cat > ~/bin/screenshot-full << 'SCREENSHOTFULL'
#!/bin/bash
# Скриншот всего экрана

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

FILENAME="screenshot_$(date +'%Y-%m-%d_%H-%M-%S')_full.png"
FILEPATH="$SCREENSHOT_DIR/$FILENAME"

scrot "$FILEPATH" 2>/dev/null

if [ -f "$FILEPATH" ]; then
    xclip -selection clipboard -t image/png -i "$FILEPATH" 2>/dev/null
    notify-send "Скриншот сохранён" "$FILENAME\nСкопирован в буфер обмена" \
        -i "$FILEPATH" -t 3000 2>/dev/null
fi
SCREENSHOTFULL

    chmod +x ~/bin/screenshot ~/bin/screenshot-full
    log "Скриншоты будут в ~/Pictures/Screenshots/"
}

# ===================== СКРИПТ ЗАПУСКА TELEGRAM =====================
create_telegram_launcher() {
    log "Создание универсального запускателя Telegram..."

    mkdir -p ~/bin

    cat > ~/bin/telegram << 'TELEGRAM'
#!/bin/bash
# Универсальный запуск Telegram (проверяет разные варианты бинарей)

if command -v telegram-desktop &>/dev/null; then
    exec telegram-desktop "$@"
elif command -v Telegram &>/dev/null; then
    exec Telegram "$@"
elif [ -x "/usr/bin/telegram-desktop" ]; then
    exec /usr/bin/telegram-desktop "$@"
elif [ -x "/opt/telegram-desktop/Telegram" ]; then
    exec /opt/telegram-desktop/Telegram "$@"
else
    notify-send "Telegram" "Telegram не установлен!" -u critical
    exit 1
fi
TELEGRAM

    chmod +x ~/bin/telegram
    log "Telegram запускатель создан"
}

# ===================== СБОРКА DWM =====================
build_dwm() {
    download_tool "dwm" \
        "https://gitee.com/mirrors/dwm.git" \
        "https://codeberg.org/gergelylaba/dwm.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/dwm/dwm-6.5.tar.gz"

    cd ~/suckless/dwm

    cat > config.h << 'DWMCONFIG'
/* ============================================================
 *  DWM config.h — Тёплый монохром v9
 * ============================================================ */

static const unsigned int borderpx  = 2;
static const unsigned int snap      = 16;
static const int showbar            = 1;
static const int topbar             = 1;
static const char *fonts[]          = {
    "JetBrains Mono:size=11",
    "Font Awesome 6 Free:size=11"
};
static const char dmenufont[]       = "JetBrains Mono:size=11";

/* Тёплая монохромная палитра */
static const char col_bg[]          = "#0c0b0a";
static const char col_bg_sel[]      = "#1c1a18";
static const char col_fg[]          = "#b5ada6";
static const char col_accent[]      = "#f5efe6";
static const char col_border[]      = "#3a3632";
static const char col_border_sel[]  = "#f5efe6";

static const char *colors[][3]      = {
    [SchemeNorm]   = { col_fg,     col_bg,     col_border     },
    [SchemeSel]    = { col_accent, col_bg_sel, col_border_sel },
};

static const char *tags[] = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" };

static const Rule rules[] = {
    { "Steam",            NULL, NULL, 1 << 3, 1, -1 },
    { "TelegramDesktop",  NULL, NULL, 1 << 2, 0, -1 },
    { "telegram-desktop", NULL, NULL, 1 << 2, 0, -1 },
    { "Gimp",             NULL, NULL, 0,      1, -1 },
    { "pavucontrol",      NULL, NULL, 0,      1, -1 },
    { "stalonetray",      NULL, NULL, 0,      1, -1 },
};

static const float mfact     = 0.55;
static const int nmaster     = 1;
static const int resizehints = 0;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
    { "[]=", tile },
    { "><>", NULL },
    { "[M]", monocle },
};

#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
    { MODKEY,                       KEY, view,       {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask,           KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|ShiftMask,             KEY, tag,        {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask|ShiftMask, KEY, toggletag,  {.ui = 1 << TAG} },

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static char dmenumon[2] = "0";
static const char *dmenucmd[]    = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont,
    "-nb", col_bg, "-nf", col_fg, "-sb", col_bg_sel, "-sf", col_accent,
    "-l", "20", NULL };
static const char *termcmd[]         = { "alacritty", NULL };
static const char *browsercmd[]      = { "zen-browser", NULL };
static const char *filemgrcmd[]      = { "alacritty", "-e", "lf", NULL };
static const char *telegramcmd[]     = { "sh", "-c", "$HOME/bin/telegram", NULL };
static const char *steamcmd[]        = { "steam", NULL };
static const char *screenshot[]      = { "sh", "-c", "$HOME/bin/screenshot", NULL };
static const char *screenshotfull[]  = { "sh", "-c", "$HOME/bin/screenshot-full", NULL };
static const char *lockcmd[]         = { "slock", NULL };

static const char *vol_up[]   = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *vol_down[] = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *vol_mute[] = { "pactl", "set-sink-mute",   "@DEFAULT_SINK@", "toggle", NULL };

static const char *bri_up[]   = { "brightnessctl", "set", "+10%", NULL };
static const char *bri_down[] = { "brightnessctl", "set", "10%-", NULL };

#include <X11/XF86keysym.h>

static const Key keys[] = {
    /* ─── Запуск программ ─── */
    { MODKEY,                       XK_d,      spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
    { MODKEY,                       XK_w,      spawn,          {.v = browsercmd } },
    { MODKEY,                       XK_e,      spawn,          {.v = filemgrcmd } },
    { MODKEY,                       XK_t,      spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,             XK_s,      spawn,          {.v = steamcmd } },
    { MODKEY|ShiftMask,             XK_l,      spawn,          {.v = lockcmd } },
    { 0,                            XK_Print,  spawn,          {.v = screenshot } },
    { ShiftMask,                    XK_Print,  spawn,          {.v = screenshotfull } },

    /* ─── Громкость / яркость ─── */
    { 0, XF86XK_AudioRaiseVolume, spawn, {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume, spawn, {.v = vol_down } },
    { 0, XF86XK_AudioMute,       spawn, {.v = vol_mute } },
    { 0, XF86XK_MonBrightnessUp,   spawn, {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown, spawn, {.v = bri_down } },

    /* ─── Управление окнами ─── */
    { MODKEY,           XK_j,      focusstack,     {.i = +1 } },
    { MODKEY,           XK_k,      focusstack,     {.i = -1 } },
    { MODKEY,           XK_h,      setmfact,       {.f = -0.05} },
    { MODKEY,           XK_l,      setmfact,       {.f = +0.05} },
    { MODKEY,           XK_i,      incnmaster,     {.i = +1 } },
    { MODKEY|ShiftMask, XK_i,      incnmaster,     {.i = -1 } },
    { MODKEY|ShiftMask, XK_Return, zoom,           {0} },
    { MODKEY,           XK_Tab,    view,           {0} },

    /* ─── Закрытие / выход ─── */
    { MODKEY|ShiftMask,             XK_q, killclient, {0} },
    { MODKEY|ControlMask|ShiftMask, XK_q, quit,       {0} },

    /* ─── Раскладки окон ─── */
    { MODKEY,             XK_semicolon, setlayout, {.v = &layouts[0]} },
    { MODKEY|ShiftMask,   XK_semicolon, setlayout, {.v = &layouts[1]} },
    { MODKEY,             XK_m,         setlayout, {.v = &layouts[2]} },
    { MODKEY,             XK_n,         setlayout, {0} },
    { MODKEY|ShiftMask,   XK_n,         togglefloating, {0} },

    /* ─── Бар ─── */
    { MODKEY,           XK_b,      togglebar, {0} },

    /* ─── Мониторы ─── */
    { MODKEY,           XK_comma,  focusmon, {.i = -1 } },
    { MODKEY,           XK_period, focusmon, {.i = +1 } },
    { MODKEY|ShiftMask, XK_comma,  tagmon,   {.i = -1 } },
    { MODKEY|ShiftMask, XK_period, tagmon,   {.i = +1 } },

    /* ─── Все теги ─── */
    { MODKEY,           XK_0, view, {.ui = ~0 } },
    { MODKEY|ShiftMask, XK_0, tag,  {.ui = ~0 } },

    /* ─── Теги 1-9 ─── */
    TAGKEYS(XK_1, 0) TAGKEYS(XK_2, 1) TAGKEYS(XK_3, 2)
    TAGKEYS(XK_4, 3) TAGKEYS(XK_5, 4) TAGKEYS(XK_6, 5)
    TAGKEYS(XK_7, 6) TAGKEYS(XK_8, 7) TAGKEYS(XK_9, 8)
};

static const Button buttons[] = {
    { ClkLtSymbol,   0,      Button1, setlayout,      {0} },
    { ClkLtSymbol,   0,      Button3, setlayout,      {.v = &layouts[2]} },
    { ClkWinTitle,   0,      Button2, zoom,           {0} },
    { ClkStatusText, 0,      Button2, spawn,          {.v = termcmd } },
    { ClkClientWin,  MODKEY, Button1, movemouse,      {0} },
    { ClkClientWin,  MODKEY, Button2, togglefloating, {0} },
    { ClkClientWin,  MODKEY, Button3, resizemouse,    {0} },
    { ClkTagBar,     0,      Button1, view,           {0} },
    { ClkTagBar,     0,      Button3, toggleview,     {0} },
    { ClkTagBar,     MODKEY, Button1, tag,            {0} },
    { ClkTagBar,     MODKEY, Button3, toggletag,      {0} },
};
DWMCONFIG

    sudo make clean install
    log "DWM установлен!"
    cd ~/suckless
}

# ===================== СБОРКА DMENU =====================
build_dmenu() {
    download_tool "dmenu" \
        "https://gitee.com/mirrors/dmenu.git" \
        "https://codeberg.org/gergelylaba/dmenu.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/tools/dmenu-5.3.tar.gz"

    cd ~/suckless/dmenu

    cat > config.h << 'DMENUCONFIG'
static int topbar = 1;

static const char *fonts[] = {
	"JetBrains Mono:size=11"
};
static const char *prompt      = NULL;
static const char *colors[SchemeLast][2] = {
	[SchemeNorm] = { "#b5ada6", "#0c0b0a" },
	[SchemeSel]  = { "#f5efe6", "#1c1a18" },
	[SchemeOut]  = { "#0c0b0a", "#3a3632" },
};
static unsigned int lines      = 20;

static const char worddelimiters[] = " ";
DMENUCONFIG

    sudo make clean install
    log "dmenu установлен!"
    cd ~/suckless
}

# ===================== СБОРКА SLOCK =====================
build_slock() {
    download_tool "slock" \
        "https://gitee.com/mirrors/slock.git" \
        "https://codeberg.org/gergelylaba/slock.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/tools/slock-1.5.tar.gz"

    cd ~/suckless/slock

    cat > config.h << 'SLOCKCONFIG'
/* Пользователь и группа */
static const char *user  = "nobody";
static const char *group = "nobody";

static const char *colorname[NUMCOLS] = {
	[INIT] =   "#0c0b0a",
	[INPUT] =  "#f5efe6",
	[FAILED] = "#3a3632",
};

static const int failonclear = 1;
SLOCKCONFIG

    sudo make clean install

    # КРИТИЧНО! Устанавливаем SUID-бит, иначе slock не сможет проверить пароль
    sudo chmod u+s /usr/local/bin/slock

    # Проверяем
    if [ -u /usr/local/bin/slock ]; then
        log "slock установлен с правильными SUID-правами!"
    else
        warn "SUID-бит не установлен! Установите вручную: sudo chmod u+s /usr/local/bin/slock"
    fi

    cd ~/suckless
}

# ===================== ALACRITTY =====================
create_alacritty_config() {
    log "Создание конфига Alacritty..."

    mkdir -p ~/.config/alacritty

    cat > ~/.config/alacritty/alacritty.toml << 'ALACRITTY'
[env]
TERM = "xterm-256color"

[window]
padding = { x = 14, y = 14 }
dynamic_padding = true
decorations = "None"
opacity = 0.95

[scrolling]
history = 10000
multiplier = 3

[font]
size = 13.0

[font.normal]
family = "JetBrains Mono"
style = "Regular"

[font.bold]
family = "JetBrains Mono"
style = "Bold"

[font.italic]
family = "JetBrains Mono"
style = "Italic"

[colors.primary]
background = "#0c0b0a"
foreground = "#b5ada6"

[colors.cursor]
text    = "#0c0b0a"
cursor  = "#f5efe6"

[colors.vi_mode_cursor]
text    = "#0c0b0a"
cursor  = "#f5efe6"

[colors.selection]
text       = "#0c0b0a"
background = "#3a3632"

[colors.search.matches]
foreground = "#0c0b0a"
background = "#b5ada6"

[colors.search.focused_match]
foreground = "#0c0b0a"
background = "#f5efe6"

[colors.normal]
black   = "#0c0b0a"
red     = "#b5ada6"
green   = "#8a8278"
yellow  = "#d5cdc4"
blue    = "#7a7268"
magenta = "#a59d94"
cyan    = "#6a6258"
white   = "#b5ada6"

[colors.bright]
black   = "#3a3632"
red     = "#d5cdc4"
green   = "#a59d94"
yellow  = "#f5efe6"
blue    = "#8a8278"
magenta = "#b5ada6"
cyan    = "#7a7268"
white   = "#f5efe6"

[colors.dim]
black   = "#0c0b0a"
red     = "#6a6258"
green   = "#5a5248"
yellow  = "#7a7268"
blue    = "#4a4238"
magenta = "#6a6258"
cyan    = "#3a3632"
white   = "#8a8278"

[keyboard]
bindings = [
    { key = "V",        mods = "Control|Shift", action = "Paste" },
    { key = "C",        mods = "Control|Shift", action = "Copy" },
    { key = "Plus",     mods = "Control",       action = "IncreaseFontSize" },
    { key = "Minus",    mods = "Control",       action = "DecreaseFontSize" },
    { key = "Key0",     mods = "Control",       action = "ResetFontSize" },
    { key = "F",        mods = "Control|Shift", action = "SearchForward" },
    { key = "B",        mods = "Control|Shift", action = "SearchBackward" },
    { key = "PageUp",   mods = "Shift",         action = "ScrollPageUp" },
    { key = "PageDown", mods = "Shift",         action = "ScrollPageDown" },
    { key = "Up",       mods = "Shift",         action = "ScrollLineUp" },
    { key = "Down",     mods = "Shift",         action = "ScrollLineDown" },
    { key = "Home",     mods = "Shift",         action = "ScrollToTop" },
    { key = "End",      mods = "Shift",         action = "ScrollToBottom" },
]

[mouse]
hide_when_typing = true
ALACRITTY

    log "Alacritty настроен"
}

# ===================== STALONETRAY (СИСТЕМНЫЙ ТРЕЙ) =====================
create_tray_config() {
    log "Создание конфига трея (stalonetray)..."

    cat > ~/.stalonetrayrc << 'TRAY'
# Stalonetray — системный трей для DWM

# Позиция в правом верхнем углу
geometry 1x1-0+0
sticky true
window_type dock
window_layer top

# Внешний вид
background "#0c0b0a"
kludges force_icons_size
icon_gravity NE
icon_size 18
slot_size 24
grow_gravity NE

# Границы
window_strut auto
skip_taskbar true

# Максимальная ширина
max_geometry 10x1-0+0
TRAY

    log "Stalonetray настроен"
}

# ===================== ОТКЛЮЧЕНИЕ АКСЕЛЕРАЦИИ МЫШИ =====================
create_mouse_config() {
    log "Отключение акселерации мыши..."

    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/50-mouse-accel.conf > /dev/null << 'MOUSECONF'
Section "InputClass"
    Identifier "Mouse - No Acceleration"
    MatchIsPointer "yes"
    Option "AccelProfile" "flat"
    Option "AccelSpeed" "0"
    Option "TransformationMatrix" "1 0 0 0 1 0 0 0 1"
EndSection

Section "InputClass"
    Identifier "Touchpad - No Acceleration"
    MatchIsTouchpad "yes"
    Option "AccelProfile" "flat"
    Option "AccelSpeed" "0"
EndSection
MOUSECONF

    log "Акселерация мыши отключена"
}

# ===================== НОЧНОЙ РЕЖИМ =====================
create_nightshift() {
    log "Создание автозатемнения..."

    mkdir -p ~/bin

    cat > ~/bin/nightshift << 'NIGHTSHIFT'
#!/bin/bash
get_gamma_and_brightness() {
    local hour=$1
    local minute=$2
    local total_minutes=$(( hour * 60 + minute ))
    local brightness gamma_r gamma_g gamma_b

    if [ $total_minutes -ge 360 ] && [ $total_minutes -lt 540 ]; then
        local progress=$(echo "scale=4; ($total_minutes - 360) / 180" | bc)
        brightness=$(echo "scale=4; 0.85 + 0.15 * $progress" | bc)
        gamma_r="1.0"
        gamma_g=$(echo "scale=4; 0.90 + 0.10 * $progress" | bc)
        gamma_b=$(echo "scale=4; 0.80 + 0.20 * $progress" | bc)
    elif [ $total_minutes -ge 540 ] && [ $total_minutes -lt 1080 ]; then
        brightness="1.0"
        gamma_r="1.0"; gamma_g="1.0"; gamma_b="1.0"
    elif [ $total_minutes -ge 1080 ] && [ $total_minutes -lt 1260 ]; then
        local progress=$(echo "scale=4; ($total_minutes - 1080) / 180" | bc)
        brightness=$(echo "scale=4; 1.0 - 0.20 * $progress" | bc)
        gamma_r="1.0"
        gamma_g=$(echo "scale=4; 1.0 - 0.12 * $progress" | bc)
        gamma_b=$(echo "scale=4; 1.0 - 0.25 * $progress" | bc)
    elif [ $total_minutes -ge 1260 ] && [ $total_minutes -lt 1440 ]; then
        local progress=$(echo "scale=4; ($total_minutes - 1260) / 180" | bc)
        brightness=$(echo "scale=4; 0.80 - 0.10 * $progress" | bc)
        gamma_r="1.0"
        gamma_g=$(echo "scale=4; 0.88 - 0.05 * $progress" | bc)
        gamma_b=$(echo "scale=4; 0.75 - 0.10 * $progress" | bc)
    else
        brightness="0.70"
        gamma_r="1.0"; gamma_g="0.83"; gamma_b="0.65"
    fi
    echo "$brightness $gamma_r $gamma_g $gamma_b"
}

apply_settings() {
    local hour=$(date +%-H)
    local minute=$(date +%-M)
    local values=$(get_gamma_and_brightness $hour $minute)
    local brightness=$(echo "$values" | awk '{print $1}')
    local gr=$(echo "$values" | awk '{print $2}')
    local gg=$(echo "$values" | awk '{print $3}')
    local gb=$(echo "$values" | awk '{print $4}')

    for output in $(xrandr --query | grep " connected" | awk '{print $1}'); do
        xrandr --output "$output" --brightness "$brightness" --gamma "${gr}:${gg}:${gb}" 2>/dev/null
    done
}

while true; do
    apply_settings
    sleep 60
done
NIGHTSHIFT

    chmod +x ~/bin/nightshift

    cat > ~/bin/nightshift-reset << 'NSRESET'
#!/bin/bash
for output in $(xrandr --query | grep " connected" | awk '{print $1}'); do
    xrandr --output "$output" --brightness 1.0 --gamma 1.0:1.0:1.0
done
NSRESET
    chmod +x ~/bin/nightshift-reset

    if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
}

# ===================== СТАТУС-БАР =====================
create_statusbar() {
    log "Создание статус-бара..."

    cat > ~/suckless/dwm-statusbar.sh << 'STATUSBAR'
#!/bin/bash
while true; do
    DATE=$(date +'%a %d %b')
    TIME=$(date +'%H:%M')

    BAT=""
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        BAT_CAP=$(cat /sys/class/power_supply/BAT0/capacity)
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$BAT_STATUS" = "Charging" ]; then
            BAT=" | CHR:${BAT_CAP}%"
        else
            BAT=" | BAT:${BAT_CAP}%"
        fi
    fi

    VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1 | awk '{print $5}' || echo "N/A")
    MUTE=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    if [ "$MUTE" = "yes" ]; then
        VOL="MUTED"
    else
        VOL="VOL:$VOL"
    fi

    RAM=$(free -h | awk '/Mem:/ {print $3"/"$2}')
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

    # Отступ справа под трей (примерно 200px = ~15 пробелов)
    xsetroot -name " CPU:${CPU}% | RAM:${RAM} | ${VOL}${BAT} | ${DATE} ${TIME}                     "
    sleep 2
done
STATUSBAR

    chmod +x ~/suckless/dwm-statusbar.sh
}

# ===================== XINITRC =====================
create_xinitrc() {
    log "Создание .xinitrc..."

    cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh
# ─── Системные раскладки клавиатуры настроены в системе, не трогаем ───

# Курсор
xsetroot -cursor_name left_ptr &

# Отключение акселерации мыши через xinput
sleep 1
for id in $(xinput list --id-only 2>/dev/null); do
    xinput set-prop "$id" "libinput Accel Profile Enabled" 0 1 2>/dev/null
    xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null
done &

# Композитор и фон
picom --config ~/.config/picom/picom.conf -b 2>/dev/null &
xsetroot -solid "#0c0b0a" &

# Уведомления и D-Bus / polkit
dunst &
lxsession &

# ─── СИСТЕМНЫЙ ТРЕЙ ───
sleep 2
stalonetray &

# ─── ИКОНКИ В ТРЕЕ ───
sleep 3
nm-applet &                          # Wi-Fi / сеть
blueman-applet &                     # Bluetooth
pasystray 2>/dev/null &              # Звук (если установлен)

# ─── АВТОБЛОКИРОВКА ───
if command -v xidlehook &>/dev/null; then
    xidlehook \
        --not-when-fullscreen \
        --not-when-audio \
        --timer 600 'slock' '' &
fi

# ─── СТАТУС-БАР И НОЧНОЙ РЕЖИМ ───
~/suckless/dwm-statusbar.sh &
~/bin/nightshift &

exec dwm
XINITRC

    chmod +x ~/.xinitrc
    log ".xinitrc создан"
}

# ===================== PICOM =====================
create_picom_config() {
    mkdir -p ~/.config/picom
    cat > ~/.config/picom/picom.conf << 'PICOM'
backend = "xrender";
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-color = "#0c0b0a";

shadow-exclude = [
    "class_g = 'stalonetray'",
    "name = 'stalonetray'"
];

inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;

fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
fade-delta = 5;

corner-radius = 0;
vsync = true;
PICOM
}

# ===================== DUNST =====================
create_dunst_config() {
    mkdir -p ~/.config/dunst
    cat > ~/.config/dunst/dunstrc << 'DUNST'
[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 100
    origin = top-right
    offset = 20x40
    frame_width = 2
    frame_color = "#3a3632"
    font = JetBrains Mono 10
    corner_radius = 0

[urgency_low]
    background = "#0c0b0a"
    foreground = "#b5ada6"
    timeout = 5

[urgency_normal]
    background = "#0c0b0a"
    foreground = "#d5cdc4"
    timeout = 10

[urgency_critical]
    background = "#1c1a18"
    foreground = "#f5efe6"
    frame_color = "#f5efe6"
    timeout = 0
DUNST
}

# ===================== LF =====================
create_lf_config() {
    mkdir -p ~/.config/lf
    cat > ~/.config/lf/lfrc << 'LFRC'
set ratios 1:2:3
set hidden true
set ignorecase true
set icons true

map <enter> open
map D delete
map x cut
map y copy
map p paste
map r rename
map . set hidden!
map R reload
map dd delete

cmd open ${{
    case $(file --mime-type "$f" -bL) in
        text/*|application/json) $EDITOR "$f";;
        image/*) feh "$f" &;;
        video/*|audio/*) mpv "$f" &;;
        application/pdf) zathura "$f" &;;
        *) xdg-open "$f" &;;
    esac
}}
LFRC
}

# ===================== GTK ТЕМА =====================
create_gtk_theme() {
    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-application-prefer-dark-theme=1
GTK3

    cat > ~/.gtkrc-2.0 << 'GTK2'
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Adwaita"
gtk-font-name="JetBrains Mono 11"
GTK2
}

# ===================== СЕССИЯ DWM =====================
create_session() {
    sudo mkdir -p /usr/share/xsessions
    sudo tee /usr/share/xsessions/dwm.desktop > /dev/null << 'SESSION'
[Desktop Entry]
Encoding=UTF-8
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/dwm
Icon=dwm
Type=XSession
SESSION
}

# ===================== ШПАРГАЛКА =====================
create_cheatsheet() {
    cat > ~/dwm-keybinds.txt << 'CHEAT'
╔══════════════════════════════════════════════════════════════╗
║                    DWM KEYBINDINGS v9                        ║
╠══════════════════════════════════════════════════════════════╣
║  ЗАПУСК                                                      ║
║  Super + Enter        — Терминал (Alacritty)                 ║
║  Super + D            — dmenu                                ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — Файловый менеджер                    ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Print Screen         — Скриншот области                     ║
║  Shift + Print        — Скриншот всего экрана                ║
║                                                              ║
║  БЛОКИРОВКА                                                  ║
║  Super + Shift + L    — Заблокировать                        ║
║  Автоблокировка       — Через 10 минут простоя               ║
║                                                              ║
║  ОКНА                                                        ║
║  Super + J/K          — Фокус                                ║
║  Super + H/L          — Размер master                        ║
║  Super + Shift+Enter  — Сделать master                       ║
║  Super + Shift + Q    — Закрыть                              ║
║  Super + ;            — Tile   |  Super + Shift + ; = Float  ║
║  Super + M            — Monocle                              ║
║  Super + N            — Переключить раскладку                ║
║  Super + Shift + N    — Плавающее окно                       ║
║  Super + B            — Скрыть панель                        ║
║                                                              ║
║  ТЕГИ (рабочие столы)                                        ║
║  Super + 1..9         — Переключиться                        ║
║  Super + Shift + 1..9 — Перенести окно                       ║
║                                                              ║
║  ВЫХОД                                                       ║
║  Ctrl+Super+Shift+Q   — Выйти из DWM                         ║
╚══════════════════════════════════════════════════════════════╝
CHEAT
}

# ===================== ПРОВЕРКА SLOCK =====================
verify_slock() {
    log "Проверка блокировщика slock..."

    if [ ! -f /usr/local/bin/slock ]; then
        warn "slock не найден в /usr/local/bin/!"
        return
    fi

    if [ -u /usr/local/bin/slock ]; then
        log "✓ slock имеет SUID-бит — блокировка будет работать"
    else
        warn "✗ SUID-бит отсутствует, устанавливаю..."
        sudo chmod u+s /usr/local/bin/slock
        if [ -u /usr/local/bin/slock ]; then
            log "✓ SUID установлен"
        else
            err "Не удалось установить SUID! Выполните вручную: sudo chmod u+s /usr/local/bin/slock"
        fi
    fi
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Warm Monochrome — CachyOS / Arch      ║${NC}"
    echo -e "${CYAN}║   v9.0  Трей · Скриншоты · Исправления      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    install_packages
    install_yay
    install_aur_packages

    build_dwm
    build_dmenu
    build_slock
    verify_slock

    create_screenshot_script
    create_telegram_launcher
    create_alacritty_config
    create_tray_config
    create_mouse_config
    create_nightshift
    create_statusbar
    create_xinitrc
    create_picom_config
    create_dunst_config
    create_lf_config
    create_gtk_theme
    create_session
    create_cheatsheet

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Что нового в v9.0:"
    echo "  ✓ Скриншоты → ~/Pictures/Screenshots/"
    echo "  ✓ Print Screen — область, Shift+Print — весь экран"
    echo "  ✓ Скриншоты копируются в буфер обмена автоматически"
    echo "  ✓ slock: SUID-бит установлен (блокировка работает)"
    echo "  ✓ Telegram — универсальный запускатель ~/bin/telegram"
    echo "  ✓ Системный трей: stalonetray + nm-applet + blueman"
    echo "  ✓ Раскладка клавиатуры — не трогаем системную настройку"
    echo ""
    info "Проверьте блокировку сейчас: slock"
    info "Проверьте Telegram: ~/bin/telegram"
    echo ""
    info "Запуск: перезагрузите ПК → выберите 'DWM'"
    echo ""
}

main "$@"
