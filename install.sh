#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch
# Версия 11.2 — Расширенная палитра оттенков + автозапуск nightshift

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
        libnotify \
        openssh bc \
        imagemagick \
        xsettingsd \
        gnome-themes-extra adwaita-icon-theme \
        gsettings-desktop-schemas dconf
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

    info "i3lock-color..."
    if yay -S --needed --noconfirm i3lock-color; then
        log "i3lock-color установлен!"
    else
        warn "i3lock-color не собрался, ставим обычный i3lock..."
        sudo pacman -S --needed --noconfirm i3lock
    fi

    info "Zen Browser..."
    yay -S --needed --noconfirm zen-browser-bin || \
    yay -S --needed --noconfirm zen-browser || \
        warn "Zen Browser не найден."

    info "Telegram..."
    sudo pacman -S --needed --noconfirm telegram-desktop || \
        yay -S --needed --noconfirm telegram-desktop

    info "Proton..."
    yay -S --needed --noconfirm proton-cachyos-bin 2>/dev/null || \
    yay -S --needed --noconfirm proton-cachyos 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Proton не найден, установите через Steam."

    info "xidlehook..."
    yay -S --needed --noconfirm xidlehook 2>/dev/null || \
        warn "xidlehook не установлен."
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
        log "$name загружен!"
        return 0
    fi

    warn "Codeberg..."
    if git clone --depth 1 "$codeberg_url" "$name" 2>/dev/null; then
        log "$name загружен!"
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
        log "$name загружен!"
        return 0
    fi

    err "Не удалось загрузить $name!"
}

# ===================== СБОРКА DWM =====================
build_dwm() {
    download_tool "dwm" \
        "https://gitee.com/mirrors/dwm.git" \
        "https://codeberg.org/gergelylaba/dwm.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/dwm/dwm-6.5.tar.gz"

    cd ~/suckless/dwm

    log "Применение патча systray..."
    local SYSTRAY_APPLIED=0

    if wget --timeout=10 -qO dwm-systray.diff \
        "https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff" 2>/dev/null || \
       curl -sLo dwm-systray.diff \
        "https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff" 2>/dev/null; then

        if patch -p1 --forward < dwm-systray.diff 2>/dev/null; then
            SYSTRAY_APPLIED=1
            log "Патч systray применён!"
        else
            warn "Патч systray не применился."
            git checkout -- . 2>/dev/null || true
        fi
    fi

    cat > config.h << 'DWMCONFIG'
/* DWM config.h — Тёплый монохром v11.2 */

static const unsigned int borderpx       = 2;
static const unsigned int snap           = 16;
static const unsigned int systraypinning = 0;
static const unsigned int systrayonleft  = 0;
static const unsigned int systrayspacing = 4;
static const int systraypinningfailfirst = 1;
static const int showsystray             = 1;
static const int showbar                 = 1;
static const int topbar                  = 1;

static const char *fonts[]          = {
    "JetBrains Mono:size=11",
    "Font Awesome 6 Free:size=11"
};
static const char dmenufont[]       = "JetBrains Mono:size=11";

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
static const char *lockcmd[]         = { "sh", "-c", "$HOME/bin/lockscreen", NULL };

static const char *vol_up[]   = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *vol_down[] = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *vol_mute[] = { "pactl", "set-sink-mute",   "@DEFAULT_SINK@", "toggle", NULL };
static const char *bri_up[]   = { "brightnessctl", "set", "+10%", NULL };
static const char *bri_down[] = { "brightnessctl", "set", "10%-", NULL };

#include <X11/XF86keysym.h>

static const Key keys[] = {
    { MODKEY,                       XK_d,      spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
    { MODKEY,                       XK_w,      spawn,          {.v = browsercmd } },
    { MODKEY,                       XK_e,      spawn,          {.v = filemgrcmd } },
    { MODKEY,                       XK_t,      spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,             XK_s,      spawn,          {.v = steamcmd } },
    { MODKEY|ShiftMask,             XK_l,      spawn,          {.v = lockcmd } },
    { 0,                            XK_Print,  spawn,          {.v = screenshot } },
    { ShiftMask,                    XK_Print,  spawn,          {.v = screenshotfull } },

    { 0, XF86XK_AudioRaiseVolume, spawn, {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume, spawn, {.v = vol_down } },
    { 0, XF86XK_AudioMute,       spawn, {.v = vol_mute } },
    { 0, XF86XK_MonBrightnessUp,   spawn, {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown, spawn, {.v = bri_down } },

    { MODKEY,           XK_j,      focusstack,     {.i = +1 } },
    { MODKEY,           XK_k,      focusstack,     {.i = -1 } },
    { MODKEY,           XK_h,      setmfact,       {.f = -0.05} },
    { MODKEY,           XK_l,      setmfact,       {.f = +0.05} },
    { MODKEY,           XK_i,      incnmaster,     {.i = +1 } },
    { MODKEY|ShiftMask, XK_i,      incnmaster,     {.i = -1 } },
    { MODKEY|ShiftMask, XK_Return, zoom,           {0} },
    { MODKEY,           XK_Tab,    view,           {0} },

    { MODKEY|ShiftMask,             XK_q, killclient, {0} },
    { MODKEY|ControlMask|ShiftMask, XK_q, quit,       {0} },

    { MODKEY,             XK_semicolon, setlayout, {.v = &layouts[0]} },
    { MODKEY|ShiftMask,   XK_semicolon, setlayout, {.v = &layouts[1]} },
    { MODKEY,             XK_m,         setlayout, {.v = &layouts[2]} },
    { MODKEY,             XK_n,         setlayout, {0} },
    { MODKEY|ShiftMask,   XK_n,         togglefloating, {0} },

    { MODKEY,           XK_b,      togglebar, {0} },

    { MODKEY,           XK_comma,  focusmon, {.i = -1 } },
    { MODKEY,           XK_period, focusmon, {.i = +1 } },
    { MODKEY|ShiftMask, XK_comma,  tagmon,   {.i = -1 } },
    { MODKEY|ShiftMask, XK_period, tagmon,   {.i = +1 } },

    { MODKEY,           XK_0, view, {.ui = ~0 } },
    { MODKEY|ShiftMask, XK_0, tag,  {.ui = ~0 } },

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

    if [ "$SYSTRAY_APPLIED" -eq 0 ]; then
        warn "Убираю systray-переменные..."
        sed -i '/systraypinning/d' config.h
        sed -i '/systrayonleft/d' config.h
        sed -i '/systrayspacing/d' config.h
        sed -i '/systraypinningfailfirst/d' config.h
        sed -i '/showsystray/d' config.h
    fi

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
static const char *fonts[] = { "JetBrains Mono:size=11" };
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

# ===================== LOCKSCREEN =====================
create_lockscreen() {
    log "Создание скрипта блокировки экрана..."
    mkdir -p ~/bin

    cat > ~/bin/lockscreen << 'LOCKSCREEN'
#!/bin/bash
TMPIMG="/tmp/lockscreen.png"

if command -v scrot &>/dev/null; then
    scrot -o "$TMPIMG" 2>/dev/null
fi

if [ -f "$TMPIMG" ] && command -v convert &>/dev/null; then
    convert "$TMPIMG" \
        -blur 0x18 \
        -modulate 45 \
        -fill '#0c0b0a99' -draw 'rectangle 0,0 9999,9999' \
        "$TMPIMG" 2>/dev/null
fi

if i3lock --help 2>&1 | grep -q "insidecolor"; then
    if [ -f "$TMPIMG" ]; then
        i3lock \
            --image="$TMPIMG" \
            --nofork \
            --clock \
            --pass-media-keys \
            --pass-volume-keys \
            --radius=110 \
            --ring-width=7 \
            --insidecolor=00000000 \
            --insidevercolor=00000000 \
            --insidewrongcolor=00000000 \
            --ringcolor=3a3632ff \
            --ringvercolor=b5ada6ff \
            --ringwrongcolor=6a4a3aff \
            --line-uses-ring \
            --linecolor=00000000 \
            --separatorcolor=1c1a18ff \
            --keyhlcolor=f5efe6ff \
            --bshlcolor=6a6258ff \
            --verifcolor=b5ada6ff \
            --wrongcolor=f5efe6ff \
            --modifcolor=b5ada6ff \
            --timecolor=b5ada6ff \
            --datecolor=b5ada6ff \
            --layoutcolor=b5ada6ff \
            --greetercolor=f5efe6ff \
            --timestr="%H:%M" \
            --datestr="%a, %d %b" \
            --veriftext="проверка..." \
            --wrongtext="неверно" \
            --noinputtext="" \
            --locktext="блокировка..." \
            --lockfailedtext="ошибка" \
            --greetertext="" \
            --time-font="JetBrains Mono" \
            --date-font="JetBrains Mono" \
            --verif-font="JetBrains Mono" \
            --wrong-font="JetBrains Mono" \
            --timesize=52 \
            --datesize=18 \
            --verifsize=14 \
            --wrongsize=14 \
            --time-pos="ix:iy-100" \
            --date-pos="ix:iy-65" \
            --ignore-empty-password \
            --show-failed-attempts
    else
        i3lock --color=0c0b0a --nofork --clock --ignore-empty-password
    fi
else
    if [ -f "$TMPIMG" ]; then
        i3lock --image="$TMPIMG" --nofork
    else
        i3lock --color=0c0b0a --nofork
    fi
fi

rm -f "$TMPIMG"
LOCKSCREEN

    chmod +x ~/bin/lockscreen
}

# ===================== СКРИНШОТЫ =====================
create_screenshot_script() {
    log "Создание скриптов скриншотов..."
    mkdir -p ~/bin ~/Pictures/Screenshots

    cat > ~/bin/screenshot << 'SCREENSHOT'
#!/bin/bash
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILENAME="screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$SCREENSHOT_DIR/$FILENAME"
scrot -s "$FILEPATH" 2>/dev/null
if [ -f "$FILEPATH" ]; then
    xclip -selection clipboard -t image/png -i "$FILEPATH" 2>/dev/null
    notify-send "Скриншот" "$FILENAME" -i "$FILEPATH" -t 3000 2>/dev/null
fi
SCREENSHOT

    cat > ~/bin/screenshot-full << 'SCREENSHOTFULL'
#!/bin/bash
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"
FILENAME="screenshot_$(date +'%Y-%m-%d_%H-%M-%S')_full.png"
FILEPATH="$SCREENSHOT_DIR/$FILENAME"
scrot "$FILEPATH" 2>/dev/null
if [ -f "$FILEPATH" ]; then
    xclip -selection clipboard -t image/png -i "$FILEPATH" 2>/dev/null
    notify-send "Скриншот" "$FILENAME" -i "$FILEPATH" -t 3000 2>/dev/null
fi
SCREENSHOTFULL

    chmod +x ~/bin/screenshot ~/bin/screenshot-full
}

# ===================== TELEGRAM =====================
create_telegram_launcher() {
    log "Создание запускателя Telegram..."
    mkdir -p ~/bin
    cat > ~/bin/telegram << 'TELEGRAM'
#!/bin/bash
if command -v telegram-desktop &>/dev/null; then
    exec telegram-desktop "$@"
elif command -v Telegram &>/dev/null; then
    exec Telegram "$@"
elif [ -x "/opt/telegram-desktop/Telegram" ]; then
    exec /opt/telegram-desktop/Telegram "$@"
else
    notify-send "Telegram" "Не установлен!" -u critical
    exit 1
fi
TELEGRAM
    chmod +x ~/bin/telegram
}

# ===================== ALACRITTY (16 ОТТЕНКОВ) =====================
create_alacritty_config() {
    log "Создание конфига Alacritty (расширенная палитра)..."
    mkdir -p ~/.config/alacritty

    cat > ~/.config/alacritty/alacritty.toml << 'ALACRITTY'
# ============================================================
#  Alacritty — Тёплый монохром (16 оттенков)
#
#  Полная палитра от тёмного к светлому:
#  #0c0b0a  — фон (тёплый почти-чёрный)
#  #1c1a18  — фон выделения
#  #2a2622  — тёмно-коричневый
#  #3a3632  — тёплая рамка
#  #4a453f  — тёмно-серый
#  #5a544d  — средне-тёмный
#  #6a635a  — средний тусклый
#  #7a7268  — средний
#  #8a8177  — средний светлый
#  #9a9086  — светло-серый тёплый
#  #a89e93  — светлый
#  #b5ada6  — обычный текст
#  #c5bdb2  — светлее текста
#  #d5cdc4  — очень светлый
#  #e5ddd2  — почти акцент
#  #f5efe6  — кремовый белый (акцент)
# ============================================================

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
[font.bold_italic]
family = "JetBrains Mono"
style = "Bold Italic"

# ─── Основные цвета ───

[colors.primary]
background         = "#0c0b0a"
foreground         = "#b5ada6"
dim_foreground     = "#7a7268"
bright_foreground  = "#f5efe6"

[colors.cursor]
text    = "#0c0b0a"
cursor  = "#f5efe6"

[colors.vi_mode_cursor]
text    = "#0c0b0a"
cursor  = "#e5ddd2"

[colors.selection]
text       = "#f5efe6"
background = "#4a453f"

[colors.search.matches]
foreground = "#0c0b0a"
background = "#9a9086"

[colors.search.focused_match]
foreground = "#0c0b0a"
background = "#f5efe6"

[colors.footer_bar]
foreground = "#b5ada6"
background = "#1c1a18"

[colors.hints.start]
foreground = "#0c0b0a"
background = "#e5ddd2"

[colors.hints.end]
foreground = "#0c0b0a"
background = "#9a9086"

[colors.line_indicator]
foreground = "#f5efe6"
background = "None"

# ─── ANSI цвета (обычные) — тёплые оттенки серого ───
# Каждый цвет получает свой различимый оттенок

[colors.normal]
black   = "#0c0b0a"     # 0  — очень тёмный
red     = "#8a8177"     # 1  — средне-светлый (red в терминале)
green   = "#6a635a"     # 2  — средний тусклый (green)
yellow  = "#d5cdc4"     # 3  — очень светлый (yellow)
blue    = "#5a544d"     # 4  — средне-тёмный (blue)
magenta = "#9a9086"     # 5  — светло-серый (magenta)
cyan    = "#4a453f"     # 6  — тёмно-серый (cyan)
white   = "#b5ada6"     # 7  — обычный текст

# ─── ANSI цвета (яркие) — светлее обычных ───

[colors.bright]
black   = "#3a3632"     # 8  — тёплая рамка (bright black = grey)
red     = "#a89e93"     # 9  — светлый (bright red)
green   = "#8a8177"     # 10 — средне-светлый (bright green)
yellow  = "#f5efe6"     # 11 — акцент кремовый (bright yellow)
blue    = "#7a7268"     # 12 — средний (bright blue)
magenta = "#c5bdb2"     # 13 — светлее текста (bright magenta)
cyan    = "#6a635a"     # 14 — средний тусклый (bright cyan)
white   = "#f5efe6"     # 15 — акцент (bright white)

# ─── Приглушённые цвета (dim) — тёмные варианты ───

[colors.dim]
black   = "#0c0b0a"
red     = "#5a544d"
green   = "#4a453f"
yellow  = "#8a8177"
blue    = "#3a3632"
magenta = "#6a635a"
cyan    = "#2a2622"
white   = "#7a7268"

# ─── Индексированные цвета (256-color палитра) ───
# Расширяем оттенки для тонкой градации

[[colors.indexed_colors]]
index = 16
color = "#e5ddd2"

[[colors.indexed_colors]]
index = 17
color = "#a89e93"

[[colors.indexed_colors]]
index = 18
color = "#2a2622"

[[colors.indexed_colors]]
index = 19
color = "#9a9086"

[[colors.indexed_colors]]
index = 20
color = "#c5bdb2"

[[colors.indexed_colors]]
index = 21
color = "#1c1a18"

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

    log "Alacritty настроен (16+ оттенков серого)"
}

# ===================== МЫШЬ =====================
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
}

# ===================== NIGHTSHIFT + АВТОЗАПУСК =====================
create_nightshift() {
    log "Создание автозатемнения с автозапуском..."
    mkdir -p ~/bin

    cat > ~/bin/nightshift << 'NIGHTSHIFT'
#!/bin/bash
get_values() {
    local h=$1 m=$2
    local t=$(( h * 60 + m ))
    local br gr gg gb

    if [ $t -ge 360 ] && [ $t -lt 540 ]; then
        local p=$(echo "scale=4; ($t - 360) / 180" | bc)
        br=$(echo "scale=4; 0.85 + 0.15 * $p" | bc)
        gr="1.0"
        gg=$(echo "scale=4; 0.90 + 0.10 * $p" | bc)
        gb=$(echo "scale=4; 0.80 + 0.20 * $p" | bc)
    elif [ $t -ge 540 ] && [ $t -lt 1080 ]; then
        br="1.0"; gr="1.0"; gg="1.0"; gb="1.0"
    elif [ $t -ge 1080 ] && [ $t -lt 1260 ]; then
        local p=$(echo "scale=4; ($t - 1080) / 180" | bc)
        br=$(echo "scale=4; 1.0 - 0.20 * $p" | bc)
        gr="1.0"
        gg=$(echo "scale=4; 1.0 - 0.12 * $p" | bc)
        gb=$(echo "scale=4; 1.0 - 0.25 * $p" | bc)
    elif [ $t -ge 1260 ] && [ $t -lt 1440 ]; then
        local p=$(echo "scale=4; ($t - 1260) / 180" | bc)
        br=$(echo "scale=4; 0.80 - 0.10 * $p" | bc)
        gr="1.0"
        gg=$(echo "scale=4; 0.88 - 0.05 * $p" | bc)
        gb=$(echo "scale=4; 0.75 - 0.10 * $p" | bc)
    else
        br="0.70"; gr="1.0"; gg="0.83"; gb="0.65"
    fi
    echo "$br $gr $gg $gb"
}

while true; do
    vals=$(get_values $(date +%-H) $(date +%-M))
    br=$(echo "$vals" | awk '{print $1}')
    gr=$(echo "$vals" | awk '{print $2}')
    gg=$(echo "$vals" | awk '{print $3}')
    gb=$(echo "$vals" | awk '{print $4}')
    for o in $(xrandr --query | grep " connected" | awk '{print $1}'); do
        xrandr --output "$o" --brightness "$br" --gamma "${gr}:${gg}:${gb}" 2>/dev/null
    done
    sleep 60
done
NIGHTSHIFT
    chmod +x ~/bin/nightshift

    cat > ~/bin/nightshift-reset << 'NSRESET'
#!/bin/bash
for o in $(xrandr --query | grep " connected" | awk '{print $1}'); do
    xrandr --output "$o" --brightness 1.0 --gamma 1.0:1.0:1.0
done
echo "Экран сброшен."
NSRESET
    chmod +x ~/bin/nightshift-reset

    # Systemd user service
    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/nightshift.service << NSSERVICE
[Unit]
Description=Nightshift — тёплое затемнение экрана
After=graphical-session.target

[Service]
Type=simple
ExecStart=$HOME/bin/nightshift
Restart=always
RestartSec=5
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
NSSERVICE

    # Перезагружаем systemd
    systemctl --user daemon-reload 2>/dev/null || true

    # ВКЛЮЧАЕМ автозапуск (при загрузке)
    systemctl --user enable nightshift.service 2>/dev/null || true

    # ЗАПУСКАЕМ прямо сейчас (если DISPLAY доступен)
    if [ -n "$DISPLAY" ]; then
        systemctl --user start nightshift.service 2>/dev/null || \
            (nohup ~/bin/nightshift >/dev/null 2>&1 &)
        log "Nightshift ЗАПУЩЕН"
    else
        # Если DISPLAY не задан — запускаем через nohup для гарантии
        DISPLAY=:0 nohup ~/bin/nightshift >/dev/null 2>&1 &
        log "Nightshift запущен в фоне (DISPLAY=:0)"
    fi

    # Проверяем что процесс жив
    sleep 2
    if pgrep -f "$HOME/bin/nightshift" >/dev/null 2>&1; then
        log "✓ Nightshift работает (PID: $(pgrep -f "$HOME/bin/nightshift"))"
    else
        warn "Nightshift не запустился — проверьте вручную: ~/bin/nightshift &"
    fi

    if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi
}

# ===================== СТАТУС-БАР =====================
create_statusbar() {
    log "Создание статус-бара..."
    mkdir -p ~/suckless

    cat > ~/suckless/dwm-statusbar.sh << 'STATUSBAR'
#!/bin/bash
sleep 1

while true; do
    DATE=$(date +'%a %d %b')
    TIME=$(date +'%H:%M')

    BAT=""
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        BAT_CAP=$(cat /sys/class/power_supply/BAT0/capacity)
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$BAT_STATUS" = "Charging" ]; then
            BAT="CHR ${BAT_CAP}% | "
        else
            BAT="BAT ${BAT_CAP}% | "
        fi
    fi

    VOL=""
    if command -v pactl &>/dev/null; then
        V=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]*%' | head -1)
        M=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
        if [ "$M" = "yes" ]; then
            VOL="MUTE | "
        elif [ -n "$V" ]; then
            VOL="VOL ${V} | "
        fi
    fi

    RAM=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2+$4)}')

    STATUS=" ${VOL}${BAT}CPU ${CPU}% | RAM ${RAM} | ${DATE} ${TIME} "

    xsetroot -name "$STATUS"
    sleep 2
done
STATUSBAR

    chmod +x ~/suckless/dwm-statusbar.sh
}

# ===================== GTK ТЁМНАЯ ТЕМА =====================
create_gtk_theme() {
    log "Настройка тёмной GTK темы..."

    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=menu:
gtk-enable-animations=1
gtk-primary-button-warps-slider=0
gtk-toolbar-style=3
gtk-menu-images=0
gtk-button-images=0
GTK3

    mkdir -p ~/.config/gtk-4.0
    cat > ~/.config/gtk-4.0/settings.ini << 'GTK4'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-application-prefer-dark-theme=1
GTK4

    cat > ~/.gtkrc-2.0 << 'GTK2'
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Adwaita"
gtk-font-name="JetBrains Mono 11"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
GTK2

    mkdir -p ~/.config/environment.d
    cat > ~/.config/environment.d/10-dark-theme.conf << 'ENVDARK'
GTK_THEME=Adwaita-dark
QT_STYLE_OVERRIDE=Adwaita-Dark
QT_QPA_PLATFORMTHEME=gtk3
ENVDARK

    mkdir -p ~/.config/xsettingsd
    cat > ~/.config/xsettingsd/xsettingsd.conf << 'XSETTINGS'
Net/ThemeName "Adwaita-dark"
Net/IconThemeName "Adwaita"
Gtk/CursorThemeName "Adwaita"
Gtk/CursorThemeSize 24
Gtk/FontName "JetBrains Mono 11"
Gtk/DecorationLayout "menu:"
Gtk/EnableAnimations 1
Gtk/PrimaryButtonWarpsSlider 0
Gtk/ToolbarStyle 3
Gtk/MenuImages 0
Gtk/ButtonImages 0
Gtk/ApplicationPreferDarkTheme 1
XSETTINGS
}

apply_dark_theme_now() {
    log "Применение тёмной темы..."
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11' 2>/dev/null || true
    fi

    for shellrc in ~/.bashrc ~/.zshrc; do
        [ -f "$shellrc" ] || continue
        if ! grep -q "GTK_THEME=Adwaita-dark" "$shellrc"; then
            echo '' >> "$shellrc"
            echo '# Тёмная тема' >> "$shellrc"
            echo 'export GTK_THEME=Adwaita-dark' >> "$shellrc"
            echo 'export QT_QPA_PLATFORMTHEME=gtk3' >> "$shellrc"
            echo 'export QT_STYLE_OVERRIDE=Adwaita-Dark' >> "$shellrc"
        fi
    done
}

# ===================== LF (СИНХРОНИЗИРОВАНО С ALACRITTY) =====================
create_lf_config() {
    log "Создание конфига lf..."
    mkdir -p ~/.config/lf

    cat > ~/.config/lf/lfrc << 'LFRC'
set ratios 1:2:3
set hidden true
set ignorecase true
set icons false
set drawbox true
set number false
set scrolloff 5

map <enter> open
map D delete
map x cut
map y copy
map p paste
map r rename
map . set hidden!
map R reload
map dd delete
map q quit

cmd open ${{
    case $(file --mime-type "$f" -bL) in
        text/*|application/json) $EDITOR "$f";;
        image/*) feh "$f" &;;
        video/*|audio/*) mpv "$f" &;;
        application/pdf) zathura "$f" &;;
        *) xdg-open "$f" &;;
    esac
}}

cmd mkdir %{{
    printf "Directory: "
    read ans
    mkdir -p "$ans"
}}

cmd mkfile %{{
    printf "File: "
    read ans
    touch "$ans"
}}

map A mkdir
map N mkfile
LFRC

    # Цвета LF — используем ANSI индексы, которые теперь имеют разные оттенки в Alacritty
    # 0=фон 1=8a81 2=6a63 3=d5cd 4=5a54 5=9a90 6=4a45 7=b5ad(text)
    # 8=3a36 9=a89e 10=8a81(bright) 11=f5ef(accent) 12=7a72 13=c5bd 14=6a63 15=f5ef
    cat > ~/.config/lf/colors << 'LFCOLORS'
# Формат: <паттерн> <ANSI escape>
# Используем 16-цветную ANSI палитру (см. alacritty.toml)

# Директории — жирный акцент (bright white = f5efe6)
di      01;15

# Символические ссылки — курсив светло-серый
ln      03;13

# Битые ссылки — подчёркнутый тёмно-серый
or      04;08

# Обычные файлы — обычный текст (b5ada6)
fi      00;07

# Исполняемые — жирный кремовый акцент
ex      01;11

# Спец. файлы
pi      00;03
so      00;03
do      00;03
bd      00;06
cd      00;06
su      01;09
sg      01;10
tw      01;15
st      01;12
ow      00;13

# ─── Архивы (тёплый жёлтый оттенок yellow = d5cdc4) ───
*.tar   00;03
*.tgz   00;03
*.zip   00;03
*.gz    00;03
*.bz2   00;03
*.xz    00;03
*.7z    00;03
*.rar   00;03
*.deb   00;03
*.rpm   00;03

# ─── Изображения (светло-серый bright cyan = 6a635a) ───
*.jpg   00;13
*.jpeg  00;13
*.png   00;13
*.gif   00;13
*.bmp   00;13
*.svg   00;13
*.webp  00;13
*.ico   00;13

# ─── Видео (magenta = 9a9086) ───
*.mp4   00;05
*.mkv   00;05
*.avi   00;05
*.mov   00;05
*.wmv   00;05
*.webm  00;05
*.m4v   00;05

# ─── Аудио (bright magenta = c5bdb2) ───
*.mp3   00;13
*.flac  00;13
*.ogg   00;13
*.wav   00;13
*.m4a   00;13
*.aac   00;13

# ─── Документы (bright yellow = f5efe6 акцент) ───
*.pdf   01;11
*.epub  01;11
*.mobi  01;11
*.md    00;11
*.rst   00;11
*.txt   00;07
*.doc   00;11
*.docx  00;11
*.odt   00;11

# ─── Код (жирный текст, разные оттенки) ───
*.c     01;07
*.cpp   01;07
*.cc    01;07
*.h     01;07
*.hpp   01;07
*.py    01;07
*.js    01;07
*.ts    01;07
*.jsx   01;07
*.tsx   01;07
*.rs    01;07
*.go    01;07
*.rb    01;07
*.php   01;07
*.java  01;07
*.kt    01;07
*.swift 01;07
*.lua   01;07

# ─── Скрипты (bright yellow = акцент) ───
*.sh    01;11
*.bash  01;11
*.zsh   01;11
*.fish  01;11

# ─── Конфиги (bright white тусклый) ───
*.conf  00;13
*.cfg   00;13
*.toml  00;13
*.yaml  00;13
*.yml   00;13
*.json  00;13
*.xml   00;13
*.ini   00;13

# ─── Веб (green = 6a635a тусклый) ───
*.html  00;02
*.htm   00;02
*.css   00;02
*.scss  00;02
*.sass  00;02

# ─── Логи (dim) ───
*.log   00;06
*.bak   00;06
*.old   00;06
*.tmp   00;06

# ─── Данные ───
*.csv   00;07
*.sql   00;07
*.db    00;06
LFCOLORS

    # LS_COLORS для ls (тоже 16-цветная палитра, синхронизирована)
    if ! grep -q "# LS_COLORS монохром" ~/.bashrc; then
        cat >> ~/.bashrc << 'BASHRC_LS'

# LS_COLORS монохром — синхронизировано с Alacritty
export LS_COLORS="di=01;97:ln=03;96:or=04;90:so=33:pi=33:ex=01;93:bd=36:cd=36:su=01;33:sg=01;32:tw=01;97:st=01;34:ow=95:*.tar=33:*.tgz=33:*.zip=33:*.gz=33:*.bz2=33:*.xz=33:*.7z=33:*.rar=33:*.jpg=95:*.jpeg=95:*.png=95:*.gif=95:*.svg=95:*.mp4=35:*.mkv=35:*.avi=35:*.mov=35:*.webm=35:*.mp3=95:*.flac=95:*.ogg=95:*.wav=95:*.pdf=01;93:*.epub=01;93:*.md=93:*.rst=93:*.txt=37:*.c=01;37:*.cpp=01;37:*.h=01;37:*.py=01;37:*.js=01;37:*.ts=01;37:*.rs=01;37:*.go=01;37:*.rb=01;37:*.sh=01;93:*.bash=01;93:*.conf=95:*.toml=95:*.yaml=95:*.json=95:*.html=32:*.css=32:*.log=36:*.bak=36"
BASHRC_LS
    fi

    log "lf настроен (палитра синхронизирована с Alacritty)"
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

# ===================== XINITRC =====================
create_xinitrc() {
    log "Создание .xinitrc..."
    cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh

xsetroot -cursor_name left_ptr &
xsetroot -solid "#0c0b0a" &

# GTK тёмная тема
xsettingsd &
sleep 0.5
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null &
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null &
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null &

export GTK_THEME=Adwaita-dark
export QT_QPA_PLATFORMTHEME=gtk3
export QT_STYLE_OVERRIDE=Adwaita-Dark
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'

# Мышь без акселерации
sleep 1
for id in $(xinput list --id-only 2>/dev/null); do
    xinput set-prop "$id" "libinput Accel Profile Enabled" 0 1 2>/dev/null
    xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null
done &

# Композитор
picom --config ~/.config/picom/picom.conf -b 2>/dev/null &

# Уведомления и polkit
dunst &
lxsession &

# Трей
sleep 2
nm-applet &
blueman-applet 2>/dev/null &

# Автоблокировка
if command -v xidlehook &>/dev/null; then
    xidlehook \
        --not-when-fullscreen \
        --not-when-audio \
        --timer 600 "$HOME/bin/lockscreen" '' &
fi

# Статус-бар
"$HOME/suckless/dwm-statusbar.sh" &

# ─── Nightshift: гарантированный запуск ───
# 1. Пробуем через systemd (основной способ)
systemctl --user start nightshift.service 2>/dev/null

# 2. Проверяем — если не запустился, запускаем напрямую
sleep 1
if ! pgrep -f "$HOME/bin/nightshift" >/dev/null 2>&1; then
    "$HOME/bin/nightshift" &
fi

exec dwm
XINITRC
    chmod +x ~/.xinitrc
}

# ===================== ШПАРГАЛКА =====================
create_cheatsheet() {
    cat > ~/dwm-keybinds.txt << 'CHEAT'
╔══════════════════════════════════════════════════════════════╗
║                    DWM KEYBINDINGS v11.2                     ║
╠══════════════════════════════════════════════════════════════╣
║  Super + Enter        — Терминал                             ║
║  Super + D            — dmenu                                ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — LF (файловый менеджер)               ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Super + Shift + L    — Заблокировать экран                  ║
║  Print                — Скриншот области                     ║
║  Shift + Print        — Скриншот всего экрана                ║
║  Super + J/K          — Переключение окон                    ║
║  Super + H/L          — Размер master                        ║
║  Super + ;            — Tile                                 ║
║  Super + M            — Monocle                              ║
║  Super + 1..9         — Теги                                 ║
║  Ctrl+Super+Shift+Q   — Выйти из DWM                         ║
╚══════════════════════════════════════════════════════════════╝

Nightshift:
  systemctl --user status nightshift     — статус
  systemctl --user restart nightshift    — перезапустить
  nightshift-reset                       — сбросить экран
CHEAT
}

# ===================== ДИАГНОСТИКА =====================
run_diagnostics() {
    echo ""
    echo -e "${CYAN}═══════════ ДИАГНОСТИКА ═══════════${NC}"

    if pgrep -f "$HOME/bin/nightshift" >/dev/null 2>&1; then
        log "✓ Nightshift РАБОТАЕТ (PID: $(pgrep -f "$HOME/bin/nightshift"))"
    else
        warn "✗ Nightshift не запущен — попробуйте: ~/bin/nightshift &"
    fi

    if systemctl --user is-enabled nightshift.service &>/dev/null; then
        log "✓ Автозапуск Nightshift ВКЛЮЧЁН (systemd)"
    else
        warn "✗ Автозапуск не включён — systemctl --user enable nightshift"
    fi

    if command -v i3lock &>/dev/null; then
        if i3lock --help 2>&1 | grep -q "insidecolor"; then
            log "✓ i3lock-color установлен"
        else
            warn "! i3lock (обычный) установлен, i3lock-color лучше"
        fi
    else
        err "✗ i3lock НЕ установлен!"
    fi

    [ -f ~/.config/alacritty/alacritty.toml ] && log "✓ Alacritty конфиг создан" || warn "✗ Alacritty конфиг отсутствует"
    [ -f ~/.config/lf/colors ] && log "✓ LF цвета настроены" || warn "✗ LF цвета отсутствуют"

    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Warm Monochrome v11.2                 ║${NC}"
    echo -e "${CYAN}║   16 оттенков + Nightshift автозапуск       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    install_packages
    install_yay
    install_aur_packages

    build_dwm
    build_dmenu

    create_lockscreen
    create_screenshot_script
    create_telegram_launcher
    create_alacritty_config
    create_mouse_config
    create_statusbar
    create_xinitrc
    create_picom_config
    create_dunst_config
    create_lf_config
    create_gtk_theme
    apply_dark_theme_now
    create_session
    create_cheatsheet

    # Nightshift — ПОСЛЕДНИМ, чтобы всё было настроено
    create_nightshift

    run_diagnostics

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Что нового в v11.2:"
    echo "  ✓ Alacritty — 16+ различающихся оттенков серого"
    echo "  ✓ LF — цвета синхронизированы с терминалом"
    echo "  ✓ Nightshift — автозапуск включён (systemd + fallback)"
    echo "  ✓ Nightshift — запущен прямо сейчас"
    echo ""
    warn "Перезагрузите ПК: reboot"
    echo ""
}

main "$@"
