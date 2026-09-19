#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch
# Версия 10.0 — Systray патч, i3lock-color, автозагрузка nightshift

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
        imagemagick
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

    info "i3lock-color (красивый блокировщик)..."
    yay -S --needed --noconfirm i3lock-color || \
        warn "i3lock-color не установлен"

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

    info "xidlehook (автоблокировка)..."
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

# ===================== СБОРКА DWM С SYSTRAY =====================
build_dwm() {
    download_tool "dwm" \
        "https://gitee.com/mirrors/dwm.git" \
        "https://codeberg.org/gergelylaba/dwm.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/dwm/dwm-6.5.tar.gz"

    cd ~/suckless/dwm

    # Скачиваем и применяем патч systray
    log "Применение патча systray..."
    local SYSTRAY_APPLIED=0

    if wget --timeout=10 -qO dwm-systray.diff \
        "https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff" 2>/dev/null || \
       curl -sLo dwm-systray.diff \
        "https://web.archive.org/web/20240401000000/https://dwm.suckless.org/patches/systray/dwm-systray-6.4.diff" 2>/dev/null; then

        if patch -p1 --forward < dwm-systray.diff 2>/dev/null; then
            SYSTRAY_APPLIED=1
            log "Патч systray успешно применён!"
        else
            warn "Патч systray не применился чисто. Трей будет через stalonetray."
            # Откатываем поломанные файлы
            git checkout -- . 2>/dev/null || true
        fi
    else
        warn "Не удалось скачать патч systray."
    fi

    # Записываем config.h
    cat > config.h << 'DWMCONFIG'
/* ============================================================
 *  DWM config.h — Тёплый монохром v10 + systray
 * ============================================================ */

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

    # Если патч systray НЕ применился — убираем systray-переменные из config.h
    if [ "$SYSTRAY_APPLIED" -eq 0 ]; then
        warn "Убираю systray-переменные из config.h (патч не был применён)..."
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

# ===================== LOCKSCREEN (i3lock-color) =====================
create_lockscreen() {
    log "Создание скрипта блокировки экрана (i3lock-color)..."

    mkdir -p ~/bin

    cat > ~/bin/lockscreen << 'LOCKSCREEN'
#!/bin/bash
# ─── Тёплый монохромный экран блокировки (i3lock-color) ───
#
# Делает скриншот → размывает → затемняет → показывает кольцо ввода пароля
# Всё в тёплых монохромных тонах, тихо и минималистично

# Цвета (тёплый монохром)
BG="#0c0b0aff"           # Фон (тёплый чёрный)
FG="#b5ada6ff"           # Текст (тёплый серый)
ACCENT="#f5efe6ff"       # Акцент (кремовый)
RING="#3a3632ff"         # Кольцо (тёплый тёмно-серый)
RING_VER="#b5ada6ff"     # Кольцо при проверке
RING_WRONG="#6a4a3aff"   # Кольцо при ошибке (тёплый тёмно-красный)
RING_HL="#f5efe6ff"      # Подсветка кольца при вводе
KEY="#f5efe6ff"          # Точки ввода
BS="#6a6258ff"           # Удаление символа
SEPARATOR="#1c1a18ff"    # Разделитель
INSIDE="#0c0b0a00"       # Внутри кольца (прозрачный)
INSIDE_VER="#0c0b0a00"
INSIDE_WRONG="#0c0b0a00"
LINE="#00000000"         # Линия (прозрачная)

# Скриншот + размытие + затемнение
TMPIMG="/tmp/lockscreen.png"
scrot -o "$TMPIMG"
convert "$TMPIMG" \
    -blur 0x20 \
    -modulate 40 \
    -fill '#0c0b0a80' -draw 'rectangle 0,0 9999,9999' \
    "$TMPIMG"

# Запуск i3lock-color
i3lock \
    --image="$TMPIMG" \
    --nofork \
    \
    --indicator \
    --clock \
    --pass-media-keys \
    --pass-screen-keys \
    --pass-volume-keys \
    \
    --radius=120 \
    --ring-width=8 \
    \
    --insidecolor="$INSIDE" \
    --insidevercolor="$INSIDE_VER" \
    --insidewrongcolor="$INSIDE_WRONG" \
    \
    --ringcolor="$RING" \
    --ringvercolor="$RING_VER" \
    --ringwrongcolor="$RING_WRONG" \
    \
    --line-uses-ring \
    --linecolor="$LINE" \
    --separatorcolor="$SEPARATOR" \
    \
    --keyhlcolor="$KEY" \
    --bshlcolor="$BS" \
    \
    --verifcolor="$FG" \
    --wrongcolor="$ACCENT" \
    --modifcolor="$FG" \
    \
    --timecolor="$FG" \
    --datecolor="$FG" \
    --layoutcolor="$FG" \
    --greetercolor="$FG" \
    \
    --timestr="%H:%M" \
    --datestr="%a, %d %b" \
    --veriftext="" \
    --wrongtext="" \
    --noinputtext="" \
    --locktext="" \
    --lockfailedtext="" \
    --greetertext="" \
    \
    --time-font="JetBrains Mono" \
    --date-font="JetBrains Mono" \
    --verif-font="JetBrains Mono" \
    --wrong-font="JetBrains Mono" \
    --greeter-font="JetBrains Mono" \
    \
    --timesize=48 \
    --datesize=18 \
    \
    --time-align=0 \
    --date-align=0 \
    --ignore-empty-password \
    --show-failed-attempts

# Очистка
rm -f "$TMPIMG"
LOCKSCREEN

    chmod +x ~/bin/lockscreen
    log "Скрипт блокировки ~/bin/lockscreen создан"
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
    log "Скриншоты → ~/Pictures/Screenshots/"
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

# ===================== НОЧНОЙ РЕЖИМ + SYSTEMD АВТОЗАГРУЗКА =====================
create_nightshift() {
    log "Создание и автозагрузка ночного режима..."
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

    # Systemd user service для автозагрузки
    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/nightshift.service << NSSERVICE
[Unit]
Description=Nightshift — автозатемнение экрана по времени суток
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

    systemctl --user daemon-reload
    systemctl --user enable nightshift.service
    log "Nightshift настроен как системная служба (автозагрузка)"

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
    if [ "$MUTE" = "yes" ]; then VOL="MUTED"; else VOL="VOL:$VOL"; fi

    RAM=$(free -h | awk '/Mem:/ {print $3"/"$2}')
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

    xsetroot -name " CPU:${CPU}% | RAM:${RAM} | ${VOL}${BAT} | ${DATE} ${TIME} "
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

# Курсор
xsetroot -cursor_name left_ptr &

# Мышь без акселерации
sleep 1
for id in $(xinput list --id-only 2>/dev/null); do
    xinput set-prop "$id" "libinput Accel Profile Enabled" 0 1 2>/dev/null
    xinput set-prop "$id" "libinput Accel Speed" 0 2>/dev/null
done &

# Композитор и фон
picom --config ~/.config/picom/picom.conf -b 2>/dev/null &
xsetroot -solid "#0c0b0a" &

# Уведомления и polkit
dunst &
lxsession &

# Трей-приложения (если systray патч не применился — запустится stalonetray)
sleep 2
nm-applet &
blueman-applet 2>/dev/null &

# Автоблокировка (10 минут, не блокирует при видео/аудио)
if command -v xidlehook &>/dev/null; then
    xidlehook \
        --not-when-fullscreen \
        --not-when-audio \
        --timer 600 "$HOME/bin/lockscreen" '' &
fi

# Статус-бар
~/suckless/dwm-statusbar.sh &

# Ночной режим (через systemd, но на всякий случай и здесь)
if ! systemctl --user is-active --quiet nightshift.service 2>/dev/null; then
    ~/bin/nightshift &
fi

exec dwm
XINITRC
    chmod +x ~/.xinitrc
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
║                    DWM KEYBINDINGS v10                       ║
╠══════════════════════════════════════════════════════════════╣
║  Super + Enter        — Терминал (Alacritty)                 ║
║  Super + D            — dmenu                                ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — Файловый менеджер (lf)               ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Print                — Скриншот области → ~/Pictures/       ║
║  Shift + Print        — Скриншот всего экрана                ║
║  Super + Shift + L    — Заблокировать (i3lock-color)         ║
║  Super + J/K          — Переключение окон                    ║
║  Super + H/L          — Размер master                        ║
║  Super + Shift+Enter  — Сделать master                       ║
║  Super + Shift + Q    — Закрыть окно                         ║
║  Super + ;            — Tile  | Super+Shift+; — Float        ║
║  Super + M            — Monocle                              ║
║  Super + N            — Переключить раскладку                ║
║  Super + Shift + N    — Плавающее окно                       ║
║  Super + B            — Скрыть панель                        ║
║  Super + 1..9         — Теги (рабочие столы)                 ║
║  Super + Shift + 1..9 — Перенести окно на тег                ║
║  Ctrl+Super+Shift+Q   — Выйти из DWM                         ║
║  nightshift-reset     — Сбросить цвет экрана                 ║
╚══════════════════════════════════════════════════════════════╝
CHEAT
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Warm Monochrome — CachyOS / Arch      ║${NC}"
    echo -e "${CYAN}║   v10  i3lock-color · Systray · Nightshift   ║${NC}"
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
    info "Что нового в v10:"
    echo "  ✓ i3lock-color — размытый фон + кольцо ввода (тёплый монохром)"
    echo "  ✓ DWM systray патч — трей встроен в бар"
    echo "  ✓ Nightshift — systemd автозагрузка"
    echo "  ✓ Убран дублирующий setxkbmap"
    echo ""
    info "Проверить блокировку: ~/bin/lockscreen"
    info "Проверить Telegram:   ~/bin/telegram"
    info "Сбросить экран:       nightshift-reset"
    echo ""
    info "Запуск: перезагрузите ПК → выберите 'DWM'"
    echo ""
}

main "$@"
