#!/bin/bash
# install.sh — DWM окружение на CachyOS/Arch
# Версия 11.4 — Поддержка ly (TUI Display Manager)

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
        gsettings-desktop-schemas dconf \
        dbus
}

# ===================== YAY =====================
install_yay() {
    if ! command -v yay &>/dev/null; then
        log "Установка yay..."
        if sudo pacman -S --needed --noconfirm yay 2>/dev/null; then
            log "yay установлен!"
        else
            cd /tmp
            rm -rf yay-bin
            if git clone --depth 1 https://aur.archlinux.org/yay-bin.git 2>/dev/null; then
                cd yay-bin
                makepkg -si --noconfirm
                cd ~
                log "yay-bin установлен!"
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
    if yay -S --needed --noconfirm i3lock-color 2>/dev/null; then
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

    if git clone --depth 1 "$gitee_url" "$name" 2>/dev/null; then
        log "$name загружен с Gitee!"
        return 0
    fi

    if git clone --depth 1 "$codeberg_url" "$name" 2>/dev/null; then
        log "$name загружен с Codeberg!"
        return 0
    fi

    if wget --timeout=10 -qO "${name}.tar.gz" "$archive_url" || \
       curl -L --connect-timeout 10 -o "${name}.tar.gz" "$archive_url"; then
        tar -xzf "${name}.tar.gz"
        local extracted_dir
        extracted_dir=$(tar -tf "${name}.tar.gz" | head -1 | cut -f1 -d"/")
        mv "$extracted_dir" "$name"
        rm "${name}.tar.gz"
        log "$name загружен из архива!"
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
/* DWM config.h — Тёплый монохром v11.4 */

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
    log "Создание скрипта блокировки..."
    mkdir -p ~/bin

    cat > ~/bin/lockscreen << 'LOCKSCREEN'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"

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
            --image="$TMPIMG" --nofork --clock \
            --pass-media-keys --pass-volume-keys \
            --radius=110 --ring-width=7 \
            --insidecolor=00000000 --insidevercolor=00000000 --insidewrongcolor=00000000 \
            --ringcolor=3a3632ff --ringvercolor=b5ada6ff --ringwrongcolor=6a4a3aff \
            --line-uses-ring --linecolor=00000000 --separatorcolor=1c1a18ff \
            --keyhlcolor=f5efe6ff --bshlcolor=6a6258ff \
            --verifcolor=b5ada6ff --wrongcolor=f5efe6ff --modifcolor=b5ada6ff \
            --timecolor=b5ada6ff --datecolor=b5ada6ff \
            --timestr="%H:%M" --datestr="%a, %d %b" \
            --veriftext="проверка..." --wrongtext="неверно" \
            --noinputtext="" --locktext="блокировка..." --lockfailedtext="ошибка" \
            --time-font="JetBrains Mono" --date-font="JetBrains Mono" \
            --verif-font="JetBrains Mono" --wrong-font="JetBrains Mono" \
            --timesize=52 --datesize=18 \
            --ignore-empty-password --show-failed-attempts
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
    log "Создание скриншотов..."
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
    log "Создание Telegram запускателя..."
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

# ===================== ALACRITTY =====================
create_alacritty_config() {
    log "Создание Alacritty..."
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

[colors.selection]
text       = "#0c0b0a"
background = "#3a3632"

[colors.normal]
black   = "#0c0b0a"
red     = "#8a8177"
green   = "#6a635a"
yellow  = "#d5cdc4"
blue    = "#5a544d"
magenta = "#9a9086"
cyan    = "#4a453f"
white   = "#b5ada6"

[colors.bright]
black   = "#3a3632"
red     = "#a89e93"
green   = "#8a8177"
yellow  = "#f5efe6"
blue    = "#7a7268"
magenta = "#c5bdb2"
cyan    = "#6a635a"
white   = "#f5efe6"

[colors.dim]
black   = "#0c0b0a"
red     = "#5a544d"
green   = "#4a453f"
yellow  = "#8a8177"
blue    = "#3a3632"
magenta = "#6a635a"
cyan    = "#2a2622"
white   = "#7a7268"

[keyboard]
bindings = [
    { key = "V",        mods = "Control|Shift", action = "Paste" },
    { key = "C",        mods = "Control|Shift", action = "Copy" },
    { key = "Plus",     mods = "Control",       action = "IncreaseFontSize" },
    { key = "Minus",    mods = "Control",       action = "DecreaseFontSize" },
    { key = "Key0",     mods = "Control",       action = "ResetFontSize" },
    { key = "F",        mods = "Control|Shift", action = "SearchForward" },
    { key = "PageUp",   mods = "Shift",         action = "ScrollPageUp" },
    { key = "PageDown", mods = "Shift",         action = "ScrollPageDown" },
    { key = "Up",       mods = "Shift",         action = "ScrollLineUp" },
    { key = "Down",     mods = "Shift",         action = "ScrollLineDown" },
]

[mouse]
hide_when_typing = true
ALACRITTY
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

# ===================== NIGHTSHIFT =====================
create_nightshift() {
    log "Создание Nightshift..."
    mkdir -p ~/bin

    cat > ~/bin/nightshift << 'NIGHTSHIFT'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"

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
    for o in $(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}'); do
        xrandr --output "$o" --brightness "$br" --gamma "${gr}:${gg}:${gb}" 2>/dev/null
    done
    sleep 60
done
NIGHTSHIFT
    chmod +x ~/bin/nightshift

    cat > ~/bin/nightshift-reset << 'NSRESET'
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
for o in $(xrandr --query 2>/dev/null | grep " connected" | awk '{print $1}'); do
    xrandr --output "$o" --brightness 1.0 --gamma 1.0:1.0:1.0
done
echo "Экран сброшен."
NSRESET
    chmod +x ~/bin/nightshift-reset

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
# Быстрый статус-бар для DWM

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"

# Первичный тест — обязательно поставим текст сразу
xsetroot -name " Загрузка... "

sleep 1

while true; do
    DATE=$(date +'%a %d %b')
    TIME=$(date +'%H:%M')

    BAT=""
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        BAT_CAP=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        if [ "$BAT_STATUS" = "Charging" ]; then
            BAT="CHR ${BAT_CAP}% | "
        elif [ -n "$BAT_CAP" ]; then
            BAT="BAT ${BAT_CAP}% | "
        fi
    fi

    VOL=""
    if command -v amixer &>/dev/null; then
        AMIXER_OUT=$(amixer sget Master 2>/dev/null)
        if [ -n "$AMIXER_OUT" ]; then
            if echo "$AMIXER_OUT" | grep -q "\[off\]"; then
                VOL="MUTE | "
            else
                V=$(echo "$AMIXER_OUT" | grep -o -m 1 '\[[0-9]*%\]' | tr -d '[]%')
                if [ -n "$V" ]; then
                    VOL="VOL ${V}% | "
                fi
            fi
        fi
    fi

    RAM=""
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        MEM_FREE=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        MEM_USED=$(( (MEM_TOTAL - MEM_FREE) / 1024 ))
        if [ $MEM_USED -ge 1024 ]; then
            RAM="$(echo "scale=1; $MEM_USED / 1024" | bc)G"
        else
            RAM="${MEM_USED}M"
        fi
    fi

    CPU=$(ps -A -o pcpu 2>/dev/null | awk '{s+=$1} END {print int(s)}')
    [ -n "$CPU" ] || CPU="0"

    STATUS=" ${VOL}${BAT}CPU ${CPU}% | RAM ${RAM} | ${DATE} ${TIME} "
    xsetroot -name "$STATUS"

    sleep 2
done
STATUSBAR

    chmod +x ~/suckless/dwm-statusbar.sh
}

# ===================== GTK ТЁМНАЯ ТЕМА =====================
create_gtk_theme() {
    log "Настройка GTK тёмной темы..."

    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
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
Gtk/ApplicationPreferDarkTheme 1
XSETTINGS
}

apply_dark_theme_now() {
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
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

# ===================== LF =====================
create_lf_config() {
    log "Создание LF..."
    mkdir -p ~/.config/lf

    cat > ~/.config/lf/lfrc << 'LFRC'
set ratios 1:2:3
set hidden true
set ignorecase true
set icons false
set drawbox true

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
LFRC

    cat > ~/.config/lf/colors << 'LFCOLORS'
di      01;15
ln      03;13
or      04;08
fi      00;07
ex      01;11
pi      00;03
so      00;03
do      00;03
bd      00;06
cd      00;06

*.tar   00;03
*.zip   00;03
*.gz    00;03
*.7z    00;03
*.jpg   00;13
*.png   00;13
*.gif   00;13
*.mp4   00;05
*.mkv   00;05
*.mp3   00;13
*.flac  00;13
*.pdf   01;11
*.md    00;11
*.txt   00;07
*.c     01;07
*.cpp   01;07
*.py    01;07
*.js    01;07
*.rs    01;07
*.sh    01;11
LFCOLORS

    if ! grep -q "LS_COLORS монохром" ~/.bashrc; then
        cat >> ~/.bashrc << 'BASHRC_LS'
# LS_COLORS монохром
export LS_COLORS="di=01;97:ln=03;96:or=04;90:so=33:pi=33:ex=01;93:bd=36:cd=36:*.tar=33:*.zip=33:*.gz=33:*.mp3=95:*.mp4=35:*.png=95:*.jpg=95:*.pdf=01;93:*.md=93:*.c=01;37:*.py=01;37:*.sh=01;93"
BASHRC_LS
    fi
}

# ===================== DWM-SESSION ДЛЯ LY (КРИТИЧНО!) =====================
create_dwm_session() {
    log "Создание dwm-session с полной инициализацией для ly..."

    # ГЛАВНОЕ: скрипт использует dbus-run-session
    # ly не создаёт D-Bus сессию — приходится делать это самим
    sudo tee /usr/local/bin/dwm-session > /dev/null << 'DWMSESSION'
#!/bin/bash
# dwm-session — Универсальный запуск DWM (для ly, sddm, gdm, startx)

# ─── 1. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ ───
# ly НЕ выставляет DISPLAY — задаём вручную
export DISPLAY="${DISPLAY:-:0}"
export XDG_SESSION_TYPE="x11"
export XDG_CURRENT_DESKTOP="DWM"
export XDG_SESSION_DESKTOP="dwm"

# PATH — ly НЕ загружает .bashrc, задаём вручную
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

# GTK тёмная тема
export GTK_THEME="Adwaita-dark"
export QT_QPA_PLATFORMTHEME="gtk3"
export QT_STYLE_OVERRIDE="Adwaita-Dark"
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

# Локаль
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# ─── 2. ЛОГИРОВАНИЕ (для диагностики) ───
LOG="$HOME/.dwm-session.log"
echo "=== $(date) — DWM session started ===" > "$LOG"
echo "DISPLAY=$DISPLAY" >> "$LOG"
echo "USER=$USER  HOME=$HOME" >> "$LOG"

# ─── 3. D-BUS СЕССИЯ ───
# ly НЕ создаёт D-Bus сессию — она нужна для gsettings, nm-applet, blueman
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    echo "Starting D-Bus session..." >> "$LOG"
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
    export DBUS_SESSION_BUS_ADDRESS
    export DBUS_SESSION_BUS_PID
fi

# ─── 4. КУРСОР И ФОН ───
xsetroot -cursor_name left_ptr &
xsetroot -solid "#0c0b0a" &

# ─── 5. ТЁМНАЯ ТЕМА GTK ───
xsettingsd &
sleep 0.3
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>>"$LOG" &
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>>"$LOG" &
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>>"$LOG" &

# ─── 6. ОТКЛЮЧЕНИЕ АКСЕЛЕРАЦИИ МЫШИ ───
(
    sleep 1
    for id in $(xinput list --id-only 2>/dev/null); do
        xinput set-prop "$id" "libinput Accel Profile Enabled" 0 1 2>/dev/null
        xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null
    done
) &

# ─── 7. ФОНОВЫЕ УТИЛИТЫ ───
picom --config "$HOME/.config/picom/picom.conf" -b 2>>"$LOG" &
dunst 2>>"$LOG" &
lxsession 2>>"$LOG" &

# ─── 8. СТАТУС-БАР (ГЛАВНОЕ!) ───
# Запускаем ДО DWM, чтобы часы появились сразу
echo "Starting statusbar..." >> "$LOG"
if [ -x "$HOME/suckless/dwm-statusbar.sh" ]; then
    "$HOME/suckless/dwm-statusbar.sh" >> "$LOG" 2>&1 &
    echo "Statusbar PID: $!" >> "$LOG"
else
    echo "ERROR: statusbar not found!" >> "$LOG"
    xsetroot -name " No statusbar! Check ~/suckless/dwm-statusbar.sh "
fi

# ─── 9. ТРЕЙ (после DWM подтянутся в systray) ───
(
    sleep 3
    nm-applet 2>>"$LOG" &
    blueman-applet 2>>"$LOG" &
) &

# ─── 10. АВТОБЛОКИРОВКА ───
if command -v xidlehook &>/dev/null; then
    xidlehook \
        --not-when-fullscreen \
        --not-when-audio \
        --timer 600 "$HOME/bin/lockscreen" '' 2>>"$LOG" &
fi

# ─── 11. НОЧНОЙ РЕЖИМ ───
if [ -x "$HOME/bin/nightshift" ]; then
    "$HOME/bin/nightshift" 2>>"$LOG" &
    echo "Nightshift PID: $!" >> "$LOG"
fi

# ─── 12. ЗАПУСК DWM ───
echo "Starting DWM..." >> "$LOG"
exec dwm
DWMSESSION

    sudo chmod +x /usr/local/bin/dwm-session
    log "Скрипт /usr/local/bin/dwm-session создан!"
}

# ===================== СЕССИЯ ДЛЯ LY =====================
create_session() {
    log "Создание файла сессии для ly..."

    # Файл сессии для ly (и других display manager)
    sudo mkdir -p /usr/share/xsessions
    sudo tee /usr/share/xsessions/dwm.desktop > /dev/null << 'SESSION'
[Desktop Entry]
Encoding=UTF-8
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/dwm-session
Icon=dwm
Type=XSession
SESSION

    # .xinitrc для startx (если ly недоступен)
    cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh
exec /usr/local/bin/dwm-session
XINITRC
    chmod +x ~/.xinitrc

    log "Сессия для ly настроена!"
}

# ===================== ШПАРГАЛКА =====================
create_cheatsheet() {
    cat > ~/dwm-keybinds.txt << 'CHEAT'
╔══════════════════════════════════════════════════════════════╗
║                    DWM KEYBINDINGS v11.4 (ly)                ║
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

Диагностика:
  cat ~/.dwm-session.log     — лог автозапуска (что не запустилось)
  pgrep -af dwm-statusbar    — работает ли часы
  pgrep -af nightshift       — работает ли ночной режим
  xrandr --verbose | head    — проверить DISPLAY
  systemctl --user status    — статус пользовательских сервисов
CHEAT
}

# ===================== ДИАГНОСТИКА =====================
run_diagnostics() {
    echo ""
    echo -e "${CYAN}═══════════ ДИАГНОСТИКА ═══════════${NC}"

    if [ -x /usr/local/bin/dwm-session ]; then
        log "✓ /usr/local/bin/dwm-session установлен"
    else
        err "✗ dwm-session НЕ создан!"
    fi

    if [ -f /usr/share/xsessions/dwm.desktop ]; then
        log "✓ Файл сессии dwm.desktop создан"
    else
        warn "✗ dwm.desktop отсутствует"
    fi

    if [ -x ~/suckless/dwm-statusbar.sh ]; then
        log "✓ Статус-бар готов"
    else
        warn "✗ Статус-бар не найден"
    fi

    if [ -x ~/bin/nightshift ]; then
        log "✓ Nightshift готов"
    else
        warn "✗ Nightshift не найден"
    fi

    if [ -x ~/bin/lockscreen ]; then
        log "✓ Lockscreen готов"
    else
        warn "✗ Lockscreen не найден"
    fi

    if command -v dbus-launch &>/dev/null; then
        log "✓ dbus-launch установлен (для ly)"
    else
        err "✗ dbus не установлен!"
    fi

    if command -v amixer &>/dev/null; then
        log "✓ amixer доступен (звук в статус-баре)"
    else
        warn "! amixer не найден"
    fi

    # Проверка ly
    if systemctl is-enabled ly.service &>/dev/null; then
        log "✓ ly service включён"
    fi

    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Warm Monochrome v11.4                 ║${NC}"
    echo -e "${CYAN}║   Полная поддержка ly (TUI display manager) ║${NC}"
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
    create_gtk_theme
    apply_dark_theme_now
    create_lf_config
    create_nightshift
    create_dwm_session
    create_session
    create_cheatsheet

    run_diagnostics

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Что нового в v11.4:"
    echo "  ✓ Полная поддержка ly (TUI display manager)"
    echo "  ✓ Ручной запуск D-Bus (ly не создаёт сессию)"
    echo "  ✓ Ручное задание DISPLAY, PATH, локали"
    echo "  ✓ Логирование в ~/.dwm-session.log"
    echo "  ✓ Часы появляются мгновенно (до запуска DWM)"
    echo ""
    warn "ВАЖНО: перезагрузите ПК!"
    info "После входа проверьте лог: cat ~/.dwm-session.log"
    echo ""
}

main "$@"
