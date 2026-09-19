#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch

set -e

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

DOTDIR="$HOME/.dwm-setup"
mkdir -p "$DOTDIR"

# ===================== ЗАВИСИМОСТИ =====================
install_packages() {
    log "Обновление системы..."
    sudo pacman -Syu --noconfirm

    log "Установка базовых пакетов..."
    sudo pacman -S --needed --noconfirm \
        base-devel git xorg xorg-xinit xorg-xrandr xorg-xsetroot \
        libx11 libxft libxinerama freetype2 fontconfig \
        picom dunst \
        xclip xdotool xsel \
        pulseaudio pavucontrol alsa-utils \
        noto-fonts noto-fonts-cjk ttf-jetbrains-mono ttf-font-awesome \
        ranger lf \
        gnome-disk-utility \
        steam \
        wget curl unzip htop neofetch \
        feh scrot brightnessctl \
        polkit lxsession \
        networkmanager network-manager-applet \
        openssh

    log "Включение NetworkManager..."
    sudo systemctl enable --now NetworkManager 2>/dev/null || true
}

# ===================== YAY (AUR HELPER) =====================
install_yay() {
    if ! command -v yay &>/dev/null; then
        log "Установка yay..."
        cd /tmp
        rm -rf yay
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
    else
        log "yay уже установлен"
    fi
}

# ===================== AUR ПАКЕТЫ =====================
install_aur_packages() {
    log "Установка AUR пакетов..."

    # Zen Browser
    yay -S --needed --noconfirm zen-browser-bin 2>/dev/null || \
    yay -S --needed --noconfirm zen-browser 2>/dev/null || \
        warn "Zen Browser: не удалось найти пакет, попробуем flatpak или ручную установку"

    # Telegram
    yay -S --needed --noconfirm telegram-desktop || \
        sudo pacman -S --needed --noconfirm telegram-desktop

    # Proton CachyOS (если доступен)
    yay -S --needed --noconfirm proton-cachyos 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Proton CachyOS не найден, установите через Steam"
}

# ===================== СБОРКА DWM =====================
build_dwm() {
    log "Сборка DWM..."
    mkdir -p ~/suckless
    cd ~/suckless

    # DWM
    if [ ! -d "dwm" ]; then
        git clone https://git.suckless.org/dwm
    fi

    # Применяем конфиг
    cat > dwm/config.h << 'DWMCONFIG'
/* ============================================================
 *  DWM config.h — Монохромная тема, панель справа
 * ============================================================ */

/* Внешний вид */
static const unsigned int borderpx  = 2;
static const unsigned int snap      = 16;
static const int showbar            = 1;
static const int topbar             = 1;
static const char *fonts[]          = { "JetBrains Mono:size=11", "Font Awesome 6 Free:size=11" };
static const char dmenufont[]       = "JetBrains Mono:size=11";

/* Монохромная чёрно-белая палитра */
static const char col_black[]       = "#000000";
static const char col_gray1[]       = "#0a0a0a";
static const char col_gray2[]       = "#1a1a1a";
static const char col_gray3[]       = "#3a3a3a";
static const char col_gray4[]       = "#b0b0b0";
static const char col_white[]       = "#e0e0e0";
static const char col_accent[]      = "#ffffff";
static const char col_border[]      = "#444444";
static const char col_border_sel[]  = "#ffffff";

static const char *colors[][3]      = {
    /*                 fg          bg          border       */
    [SchemeNorm]   = { col_gray4,  col_gray1,  col_border   },
    [SchemeSel]    = { col_accent, col_gray2,  col_border_sel },
};

/* Теги */
static const char *tags[] = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" };

static const Rule rules[] = {
    /* class          instance  title  tags mask  isfloating  monitor */
    { "Steam",        NULL,     NULL,  1 << 3,    1,          -1 },
    { "TelegramDesktop", NULL,  NULL,  1 << 2,    0,          -1 },
    { "Gimp",         NULL,     NULL,  0,         1,          -1 },
    { "pavucontrol",  NULL,     NULL,  0,         1,          -1 },
};

/* Раскладки */
static const float mfact     = 0.55;
static const int nmaster     = 1;
static const int resizehints = 0;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
    /* symbol  arrange function */
    { "[]=",   tile },
    { "><>",   NULL },    /* floating */
    { "[M]",   monocle },
};

/* Клавиши */
#define MODKEY Mod4Mask   /* Super / Win */
#define TAGKEYS(KEY,TAG) \
    { MODKEY,                       KEY, view,       {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask,           KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|ShiftMask,             KEY, tag,        {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask|ShiftMask, KEY, toggletag,  {.ui = 1 << TAG} },

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* Команды */
static char dmenumon[2] = "0";
static const char *dmenucmd[]    = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont,
    "-nb", col_gray1, "-nf", col_gray4, "-sb", col_gray2, "-sf", col_accent,
    "-l", "20", "-x", "1400", "-y", "30", "-W", "500", NULL };
static const char *termcmd[]     = { "st", NULL };
static const char *browsercmd[]  = { "zen-browser", NULL };
static const char *filemgrcmd[]  = { "st", "-e", "lf", NULL };
static const char *telegramcmd[] = { "telegram-desktop", NULL };
static const char *steamcmd[]    = { "steam", NULL };
static const char *screenshot[]  = { "scrot", "-s", "/tmp/screenshot_%Y%m%d_%H%M%S.png", NULL };

/* Громкость */
static const char *vol_up[]      = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *vol_down[]    = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *vol_mute[]    = { "pactl", "set-sink-mute",   "@DEFAULT_SINK@", "toggle", NULL };

/* Яркость */
static const char *bri_up[]      = { "brightnessctl", "set", "+10%", NULL };
static const char *bri_down[]    = { "brightnessctl", "set", "10%-", NULL };

#include <X11/XF86keysym.h>

static const Key keys[] = {
    /* modifier                 key                       function        argument */

    /* ───── Запуск программ ───── */
    { MODKEY,                   XK_d,                     spawn,          {.v = dmenucmd } },
    { MODKEY,                   XK_Return,                spawn,          {.v = termcmd } },
    { MODKEY,                   XK_w,                     spawn,          {.v = browsercmd } },
    { MODKEY,                   XK_e,                     spawn,          {.v = filemgrcmd } },
    { MODKEY,                   XK_t,                     spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,         XK_s,                     spawn,          {.v = steamcmd } },
    { 0,                        XK_Print,                 spawn,          {.v = screenshot } },

    /* ───── Громкость ───── */
    { 0, XF86XK_AudioRaiseVolume,                        spawn,          {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume,                        spawn,          {.v = vol_down } },
    { 0, XF86XK_AudioMute,                               spawn,          {.v = vol_mute } },

    /* ───── Яркость ───── */
    { 0, XF86XK_MonBrightnessUp,                         spawn,          {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown,                       spawn,          {.v = bri_down } },

    /* ───── Управление окнами ───── */
    { MODKEY,                   XK_j,                     focusstack,     {.i = +1 } },
    { MODKEY,                   XK_k,                     focusstack,     {.i = -1 } },
    { MODKEY,                   XK_h,                     setmfact,       {.f = -0.05} },
    { MODKEY,                   XK_l,                     setmfact,       {.f = +0.05} },
    { MODKEY,                   XK_i,                     incnmaster,     {.i = +1 } },
    { MODKEY|ShiftMask,         XK_i,                     incnmaster,     {.i = -1 } },
    { MODKEY|ShiftMask,         XK_Return,                zoom,           {0} },
    { MODKEY,                   XK_Tab,                   view,           {0} },

    /* ───── Закрытие / выход ───── */
    { MODKEY|ShiftMask,         XK_q,                     killclient,     {0} },
    { MODKEY|ControlMask|ShiftMask, XK_q,                 quit,           {0} },

    /* ───── Раскладки ───── */
    { MODKEY,                   XK_f,                     setlayout,      {.v = &layouts[0]} }, /* tile */
    { MODKEY|ShiftMask,         XK_f,                     setlayout,      {.v = &layouts[1]} }, /* float */
    { MODKEY,                   XK_m,                     setlayout,      {.v = &layouts[2]} }, /* monocle */
    { MODKEY,                   XK_space,                 setlayout,      {0} },
    { MODKEY|ShiftMask,         XK_space,                 togglefloating, {0} },

    /* ───── Бар ───── */
    { MODKEY,                   XK_b,                     togglebar,      {0} },

    /* ───── Мониторы ───── */
    { MODKEY,                   XK_comma,                 focusmon,       {.i = -1 } },
    { MODKEY,                   XK_period,                focusmon,       {.i = +1 } },
    { MODKEY|ShiftMask,         XK_comma,                 tagmon,         {.i = -1 } },
    { MODKEY|ShiftMask,         XK_period,                tagmon,         {.i = +1 } },

    /* ───── Все теги ───── */
    { MODKEY,                   XK_0,                     view,           {.ui = ~0 } },
    { MODKEY|ShiftMask,         XK_0,                     tag,            {.ui = ~0 } },

    /* ───── Теги 1-9 ───── */
    TAGKEYS(                    XK_1,                                     0)
    TAGKEYS(                    XK_2,                                     1)
    TAGKEYS(                    XK_3,                                     2)
    TAGKEYS(                    XK_4,                                     3)
    TAGKEYS(                    XK_5,                                     4)
    TAGKEYS(                    XK_6,                                     5)
    TAGKEYS(                    XK_7,                                     6)
    TAGKEYS(                    XK_8,                                     7)
    TAGKEYS(                    XK_9,                                     8)
};

/* Кнопки мыши на окнах */
static const Button buttons[] = {
    /* click          event mask  button    function        argument */
    { ClkLtSymbol,    0,          Button1,  setlayout,      {0} },
    { ClkLtSymbol,    0,          Button3,  setlayout,      {.v = &layouts[2]} },
    { ClkWinTitle,    0,          Button2,  zoom,           {0} },
    { ClkStatusText,  0,          Button2,  spawn,          {.v = termcmd } },
    { ClkClientWin,   MODKEY,     Button1,  movemouse,      {0} },
    { ClkClientWin,   MODKEY,     Button2,  togglefloating, {0} },
    { ClkClientWin,   MODKEY,     Button3,  resizemouse,    {0} },
    { ClkTagBar,      0,          Button1,  view,           {0} },
    { ClkTagBar,      0,          Button3,  toggleview,     {0} },
    { ClkTagBar,      MODKEY,     Button1,  tag,            {0} },
    { ClkTagBar,      MODKEY,     Button3,  toggletag,      {0} },
};
DWMCONFIG

    cd dwm
    sudo make clean install
    log "DWM установлен"
    cd ~/suckless
}

# ===================== СБОРКА ST =====================
build_st() {
    log "Сборка st (Simple Terminal)..."
    cd ~/suckless

    if [ ! -d "st" ]; then
        git clone https://git.suckless.org/st
    fi

    cat > st/config.h << 'STCONFIG'
/* st config.h — Монохромная тема */

static char *font = "JetBrains Mono:pixelsize=16:antialias=true:autohint=true";
static int borderpx = 12;

/* Terminal colors — монохром */
static const char *colorname[] = {
    /* 8 normal colors */
    [0] = "#0a0a0a", /* black   */
    [1] = "#b0b0b0", /* red     */
    [2] = "#909090", /* green   */
    [3] = "#c0c0c0", /* yellow  */
    [4] = "#808080", /* blue    */
    [5] = "#a0a0a0", /* magenta */
    [6] = "#707070", /* cyan    */
    [7] = "#d0d0d0", /* white   */

    /* 8 bright colors */
    [8]  = "#3a3a3a",
    [9]  = "#e0e0e0",
    [10] = "#b0b0b0",
    [11] = "#ffffff",
    [12] = "#a0a0a0",
    [13] = "#c0c0c0",
    [14] = "#909090",
    [15] = "#ffffff",

    [255] = 0,

    /* special */
    [256] = "#0a0a0a", /* background */
    [257] = "#d0d0d0", /* foreground */
    [258] = "#ffffff", /* cursor     */
};

unsigned int defaultfg = 257;
unsigned int defaultbg = 256;
unsigned int defaultcs = 258;
unsigned int defaultrcs = 256;

/* Misc */
static unsigned int cols = 80;
static unsigned int rows = 24;
static unsigned int tabspaces = 8;
static unsigned int defaultattr = 11;

/* Terminal type */
char *termname = "st-256color";

/* Shell */
static char *shell = "/bin/sh";
char *utmp = NULL;
char *scroll = NULL;
char *stty_args = "stty raw pass8 nl -echo -iexten -cstopb 38400";

/* Kerning / character bounding-box multipliers */
static float cwscale = 1.0;
static float chscale = 1.0;

/* word delimiter string */
wchar_t *worddelimiters = L" ";

/* selection timeouts (in milliseconds) */
static unsigned int doubleclicktimeout = 300;
static unsigned int tripleclicktimeout = 600;

/* alt screens */
int allowaltscreen = 1;
int allowwindowops = 0;

/* draw latency range in ms - from new content/incremental
   to
   
 
idle
 
 
 */
static double minlatency = 8;
static double maxlatency = 33;

/* blinking timeout (0 = off) */
static unsigned int blinktimeout = 800;

/* thickness of underline and bar cursors */
static unsigned int cursorthickness = 2;

/* bell volume.  0 = off */
static int bellvolume = 0;

/* 1: render most of the lines/blocks characters without using the font
   0: always googlerenderchar */
static int boxdraw = 0;
static int boxdraw_bold = 0;
static int boxdraw_braille = 0;

/* default TERM value */
char *termname_env = "st-256color";

/* spaces per tab */

/* Mouse shortcuts */
static MouseShortcut mshortcuts[] = {
    /* mask     button   function        argument  release */
    { XK_ANY_MOD, Button2, selpaste, {.i = 0}, 1 },
    { ShiftMask,  Button4, ttysend, {.s = "\033[5;2~"}, 0 },
    { XK_ANY_MOD, Button4, ttysend, {.s = "\031"}, 0 },
    { ShiftMask,  Button5, ttysend, {.s = "\033[6;2~"}, 0 },
    { XK_ANY_MOD, Button5, ttysend, {.s = "\005"}, 0 },
};

/* Keyboard shortcuts */
#define MODKEY Mod1Mask
#define TERMMOD (ControlMask|ShiftMask)

static Shortcut shortcuts[] = {
    /* mask        keysym       function  argument */
    { XK_ANY_MOD,  XK_Break,    sendbreak, {.i =  0} },
    { ControlMask, XK_Print,    toggleprinter, {.i =  0} },
    { ShiftMask,   XK_Print,    printscreen, {.i =  0} },
    { XK_ANY_MOD,  XK_Print,    printsel, {.i =  0} },
    { TERMMOD,     XK_Prior,    zoom,     {.f = +1} },
    { TERMMOD,     XK_Next,     zoom,     {.f = -1} },
    { TERMMOD,     XK_Home,     zoomreset, {.f =  0} },
    { TERMMOD,     XK_C,        clipcopy, {.i =  0} },
    { TERMMOD,     XK_V,        clippaste, {.i =  0} },
    { TERMMOD,     XK_Y,        selpaste, {.i =  0} },
    { ShiftMask,   XK_Insert,   selpaste, {.i =  0} },
    { TERMMOD,     XK_Num_Lock, numlock,  {.i =  0} },
};

/* Key binding for font attributes */
static uint forcemousemod = ShiftMask;
STCONFIG

    cd st
    # st может не скомпилироваться с кастомным config.h из-за несовместимости
    # Пробуем, если не получается — используем дефолт
    if ! sudo make clean install 2>/dev/null; then
        warn "Кастомный config.h для st не подошёл, собираем с дефолтом + правка цветов"
        git checkout -- config.h
        # Правим цвета в дефолтном config.def.h
        sed -i 's/unsigned int defaultfg = 7;/unsigned int defaultfg = 7;/' config.def.h
        sed -i 's/\*bg = "#......"/\*bg = "#0a0a0a"/' config.def.h 2>/dev/null || true
        cp config.def.h config.h
        sudo make clean install
    fi
    log "st установлен"
    cd ~/suckless
}

# ===================== СБОРКА DMENU =====================
build_dmenu() {
    log "Сборка dmenu..."
    cd ~/suckless

    if [ ! -d "dmenu" ]; then
        git clone https://git.suckless.org/dmenu
    fi

    cd dmenu

    # Патчим config.def.h для монохромной темы и вертикального меню справа
    cat > config.def.h << 'DMENUCONFIG'
/* dmenu config — монохром, вертикальное меню */

static int topbar = 1;

/* -fn option overrides fonts[0]; default X11 font or font set */
static const char *fonts[] = {
    "JetBrains Mono:size=11"
};

static const char *prompt = "run:";

/* Монохромные цвета */
static const char *colors[SchemeLast][2] = {
    /*                fg         bg       */
    [SchemeNorm] = { "#b0b0b0", "#0a0a0a" },
    [SchemeSel]  = { "#ffffff", "#1a1a1a" },
    [SchemeOut]  = { "#000000", "#3a3a3a" },
};

/* -l option; if nonzero, dmenu uses vertical list with given number of lines */
static unsigned int lines = 0;
static unsigned int lineheight = 0;
static unsigned int min_lineheight = 8;

/*
 * Characters not considered part of a word while deleting words
 * for example: " gy;!·\"#$%&/()=+_-,.:;*^`[]{}|"
 */
static const char worddelimiters[] = " ";

/* Size of the window border */
static unsigned int border_width = 2;
DMENUCONFIG

    cp config.def.h config.h
    sudo make clean install
    log "dmenu установлен"
    cd ~/suckless
}

# ===================== СТАТУС-БАР =====================
create_statusbar() {
    log "Создание скрипта статус-бара..."

    cat > ~/suckless/dwm-statusbar.sh << 'STATUSBAR'
#!/bin/bash
# DWM Status Bar — Монохромный

while true; do
    # Дата и время
    DATE=$(date +'%a %d %b')
    TIME=$(date +'%H:%M')

    # Батарея (если есть)
    BAT=""
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        BAT_CAP=$(cat /sys/class/power_supply/BAT0/capacity)
        BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status)
        if [ "$BAT_STATUS" = "Charging" ]; then
            BAT="CHR:${BAT_CAP}%"
        else
            BAT="BAT:${BAT_CAP}%"
        fi
        BAT=" | $BAT"
    fi

    # Громкость
    VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1 | awk '{print $5}' || echo "N/A")
    MUTE=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    if [ "$MUTE" = "yes" ]; then
        VOL="MUTED"
    else
        VOL="VOL:$VOL"
    fi

    # RAM
    RAM=$(free -h | awk '/Mem:/ {print $3"/"$2}')

    # CPU
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2+$4)}')

    xsetroot -name " CPU:${CPU}% | RAM:${RAM} | ${VOL}${BAT} | ${DATE} ${TIME} "

    sleep 2
done
STATUSBAR

    chmod +x ~/suckless/dwm-statusbar.sh
    log "Статус-бар создан"
}

# ===================== XINITRC =====================
create_xinitrc() {
    log "Создание .xinitrc..."

    cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh

# Раскладка клавиатуры (US + RU, переключение по Alt+Shift)
setxkbmap -layout us,ru -option grp:alt_shift_toggle &

# Курсор
xsetroot -cursor_name left_ptr &

# Композитинг (тени, прозрачность)
picom --config ~/.config/picom/picom.conf -b 2>/dev/null &

# Обои — сплошной чёрный
xsetroot -solid "#0a0a0a" &

# Уведомления
dunst &

# Polkit agent
lxsession &

# Статус-бар
~/suckless/dwm-statusbar.sh &

# Запуск DWM
exec dwm
XINITRC

    chmod +x ~/.xinitrc
    log ".xinitrc создан"
}

# ===================== PICOM =====================
create_picom_config() {
    log "Создание конфига picom..."

    mkdir -p ~/.config/picom
    cat > ~/.config/picom/picom.conf << 'PICOM'
# Picom — минимальный конфиг для DWM

# Backend
backend = "xrender";

# Тени
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-color = "#000000";
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'dmenu'",
    "class_g = 'Dunst'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Прозрачность
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;

# Фейдинг
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
fade-delta = 5;

# Corners
corner-radius = 0;

# VSync
vsync = true;

# Исключения
focus-exclude = [
    "class_g = 'Steam'",
    "class_g = 'steam'",
];
PICOM

    log "Picom настроен"
}

# ===================== DUNST =====================
create_dunst_config() {
    log "Создание конфига dunst..."

    mkdir -p ~/.config/dunst
    cat > ~/.config/dunst/dunstrc << 'DUNST'
[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 100
    origin = top-right
    offset = 20x40
    indicate_hidden = yes
    transparency = 0
    separator_height = 1
    padding = 12
    horizontal_padding = 15
    frame_width = 2
    frame_color = "#3a3a3a"
    separator_color = frame
    sort = yes
    idle_threshold = 120
    font = JetBrains Mono 10
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    show_age_threshold = 60
    word_wrap = yes
    corner_radius = 0
    mouse_left_click = close_current
    mouse_middle_click = do_action
    mouse_right_click = close_all

[urgency_low]
    background = "#0a0a0a"
    foreground = "#b0b0b0"
    timeout = 5

[urgency_normal]
    background = "#0a0a0a"
    foreground = "#d0d0d0"
    timeout = 10

[urgency_critical]
    background = "#1a1a1a"
    foreground = "#ffffff"
    frame_color = "#ffffff"
    timeout = 0
DUNST

    log "Dunst настроен"
}

# ===================== LF (файловый менеджер) =====================
create_lf_config() {
    log "Создание конфига lf..."

    mkdir -p ~/.config/lf
    cat > ~/.config/lf/lfrc << 'LFRC'
# LF File Manager Config

set ratios 1:2:3
set hidden true
set ignorecase true
set icons true
set previewer ~/.config/lf/preview
set cleaner ~/.config/lf/cleaner

# Бинды
map <enter> open
map D delete
map x cut
map y copy
map p paste
map r rename
map . set hidden!
map R reload
map dd delete

# Открытие файлов
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
    printf "Directory Name: "
    read ans
    mkdir -p "$ans"
}}

cmd mkfile %{{
    printf "File Name: "
    read ans
    touch "$ans"
}}

map a mkdir
map A mkfile
LFRC

    cat > ~/.config/lf/preview << 'PREVIEW'
#!/bin/sh
case "$1" in
    *.tar*) tar tf "$1";;
    *.zip) unzip -l "$1";;
    *.rar) unrar l "$1";;
    *.7z) 7z l "$1";;
    *.pdf) pdftotext "$1" -;;
    *) head -100 "$1";;
esac
PREVIEW

    cat > ~/.config/lf/cleaner << 'CLEANER'
#!/bin/sh
CLEANER

    chmod +x ~/.config/lf/preview
    chmod +x ~/.config/lf/cleaner
    log "lf настроен"
}

# ===================== GTK ТЕМА =====================
create_gtk_theme() {
    log "Настройка GTK темы..."

    mkdir -p ~/.config/gtk-3.0
    cat > ~/.config/gtk-3.0/settings.ini << 'GTK3'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
GTK3

    cat > ~/.gtkrc-2.0 << 'GTK2'
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Adwaita"
gtk-font-name="JetBrains Mono 11"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=0
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
gtk-xft-rgba="rgb"
GTK2

    log "GTK тема настроена"
}

# ===================== СКРИПТ ВЕРТИКАЛЬНОГО DMENU =====================
create_dmenu_right() {
    log "Создание скрипта вертикального dmenu справа..."

    mkdir -p ~/bin
    cat > ~/bin/dmenu-right << 'DMENURIGHT'
#!/bin/sh
# Вертикальный dmenu справа

# Получаем размер экрана
SCREEN_W=$(xrandr | grep '\*' | head -1 | awk '{print $1}' | cut -d'x' -f1)

# Ширина меню
MENU_W=400

# Позиция X (справа)
POS_X=$((SCREEN_W - MENU_W - 10))

dmenu_run \
    -l 20 \
    -fn "JetBrains Mono:size=11" \
    -nb "#0a0a0a" \
    -nf "#b0b0b0" \
    -sb "#1a1a1a" \
    -sf "#ffffff" \
    -x "$POS_X" \
    -y 30 \
    -W "$MENU_W" \
    -p "run:"
DMENURIGHT

    chmod +x ~/bin/dmenu-right

    # Добавляем ~/bin в PATH
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    fi

    log "dmenu-right создан в ~/bin/"
}

# ===================== СЕССИЯ DWM =====================
create_session() {
    log "Создание файла сессии для DM..."

    sudo tee /usr/share/xsessions/dwm.desktop > /dev/null << 'SESSION'
[Desktop Entry]
Encoding=UTF-8
Name=DWM
Comment=Dynamic Window Manager
Exec=/usr/local/bin/dwm
Icon=dwm
Type=XSession
SESSION

    log "Сессия DWM создана"
}

# ===================== СПРАВКА =====================
create_cheatsheet() {
    log "Создание шпаргалки..."

    cat > ~/dwm-keybinds.txt << 'CHEAT'
╔══════════════════════════════════════════════════════════════╗
║                    DWM KEYBINDINGS                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ЗАПУСК ПРОГРАММ                                             ║
║  ─────────────────                                           ║
║  Super + Enter        — Терминал (st)                        ║
║  Super + D            — Меню запуска (dmenu)                 ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — Файловый менеджер (lf)               ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Print Screen         — Скриншот (выделение)                 ║
║                                                              ║
║  УПРАВЛЕНИЕ ОКНАМИ                                           ║
║  ─────────────────                                           ║
║  Super + J/K          — Переключение между окнами            ║
║  Super + H/L          — Изменение размера master             ║
║  Super + Shift+Enter  — Сделать master                       ║
║  Super + Shift + Q    — Закрыть окно                         ║
║  Super + Shift+Space  — Плавающий режим                      ║
║  Super + F            — Tiling layout                        ║
║  Super + Shift + F    — Floating layout                      ║
║  Super + M            — Monocle (полный экран)               ║
║  Super + B            — Показать/скрыть бар                  ║
║                                                              ║
║  РАБОЧИЕ СТОЛЫ                                               ║
║  ─────────────────                                           ║
║  Super + 1-9          — Переключение на тег                  ║
║  Super + Shift + 1-9  — Переместить окно на тег              ║
║  Super + 0            — Показать все теги                    ║
║  Super + Tab           — Предыдущий тег                      ║
║                                                              ║
║  МОНИТОРЫ                                                    ║
║  ─────────────────                                           ║
║  Super + ,/.          — Переключение монитора                ║
║  Super + Shift + ,/.  — Переместить окно на монитор          ║
║                                                              ║
║  ЗВУК / ЯРКОСТЬ                                             ║
║  ─────────────────                                           ║
║  Fn + Volume Up/Down  — Громкость                            ║
║  Fn + Mute            — Без звука                            ║
║  Fn + Brightness      — Яркость                              ║
║                                                              ║
║  СИСТЕМА                                                     ║
║  ─────────────────                                           ║
║  Ctrl+Super+Shift+Q   — Выход из DWM                        ║
║  Alt + Shift           — Переключение раскладки (US/RU)      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
CHEAT

    log "Шпаргалка сохранена в ~/dwm-keybinds.txt"
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Monochrome Setup — CachyOS / Arch     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    info "Начинаем установку..."
    echo ""

    install_packages
    install_yay
    install_aur_packages

    build_dwm
    build_st
    build_dmenu

    create_statusbar
    create_xinitrc
    create_picom_config
    create_dunst_config
    create_lf_config
    create_gtk_theme
    create_dmenu_right
    create_session
    create_cheatsheet

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Что установлено:"
    echo "  • DWM (window manager)"
    echo "  • st (терминал)"
    echo "  • dmenu (лаунчер)"
    echo "  • lf (файловый менеджер)"
    echo "  • Zen Browser"
    echo "  • Telegram Desktop"
    echo "  • Steam + Proton"
    echo "  • GNOME Disks"
    echo "  • picom, dunst, nitrogen"
    echo ""
    info "Конфиги:"
    echo "  • DWM:    ~/suckless/dwm/config.h"
    echo "  • st:     ~/suckless/st/config.h"
    echo "  • dmenu:  ~/suckless/dmenu/config.def.h"
    echo "  • picom:  ~/.config/picom/picom.conf"
    echo "  • dunst:  ~/.config/dunst/dunstrc"
    echo "  • lf:     ~/.config/lf/lfrc"
    echo ""
    info "Запуск:"
    echo "  Если используете Display Manager — выберите сессию 'DWM'"
    echo "  Если startx — просто запустите: startx"
    echo ""
    info "Бинды: cat ~/dwm-keybinds.txt"
    echo ""
    warn "ЗАМЕЧАНИЕ: dmenu -x/-y/-W флаги требуют патча 'dmenu-xyw'."
    warn "Без этого патча dmenu откроется стандартно сверху на весь экран."
    warn "Для вертикального меню справа используйте: dmenu-right (~/bin/dmenu-right)"
    echo ""
}

main "$@"
