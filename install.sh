#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch
# Версия 3.0 — надежная загрузка исходников (без зависаний git и запросов паролей)

set -e
export GIT_TERMINAL_PROMPT=0  # Запретить git запрашивать пароли в терминале

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
        libx11 libxft libxinerama freetype2 fontconfig \
        picom dunst \
        xclip xdotool xsel \
        pavucontrol alsa-utils \
        noto-fonts noto-fonts-cjk ttf-jetbrains-mono ttf-font-awesome \
        lf \
        gnome-disk-utility \
        steam \
        wget curl tar gzip unzip htop neofetch \
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
        warn "Zen Browser не найден в AUR, установите вручную"

    # Telegram
    yay -S --needed --noconfirm telegram-desktop || \
        sudo pacman -S --needed --noconfirm telegram-desktop

    # Proton CachyOS
    yay -S --needed --noconfirm proton-cachyos 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Proton CachyOS не найден, установите через Steam"
}

# ===================== СБОРКА DWM =====================
build_dwm() {
    log "Загрузка и сборка DWM..."
    mkdir -p ~/suckless
    cd ~/suckless

    rm -rf dwm
    # Скачиваем официальный стабильный релиз архивом (качается мгновенно)
    wget -qO dwm.tar.gz https://dl.suckless.org/dwm/dwm-6.5.tar.gz || \
    curl -sLo dwm.tar.gz https://dl.suckless.org/dwm/dwm-6.5.tar.gz

    tar -xzf dwm.tar.gz
    mv dwm-6.5 dwm
    rm dwm.tar.gz

    cat > dwm/config.h << 'DWMCONFIG'
/* ============================================================
 *  DWM config.h — Монохромная тема
 * ============================================================ */

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
    /* class              instance  title  tags mask  isfloating  monitor */
    { "Steam",            NULL,     NULL,  1 << 3,    1,          -1 },
    { "TelegramDesktop",  NULL,     NULL,  1 << 2,    0,          -1 },
    { "Gimp",             NULL,     NULL,  0,         1,          -1 },
    { "pavucontrol",      NULL,     NULL,  0,         1,          -1 },
};

/* Раскладки */
static const float mfact     = 0.55;
static const int nmaster     = 1;
static const int resizehints = 0;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
    { "[]=",   tile },
    { "><>",   NULL },    /* floating */
    { "[M]",   monocle },
};

/* Клавиши */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
    { MODKEY,                       KEY, view,       {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask,           KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|ShiftMask,             KEY, tag,        {.ui = 1 << TAG} }, \
    { MODKEY|ControlMask|ShiftMask, KEY, toggletag,  {.ui = 1 << TAG} },

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static char dmenumon[2] = "0";
static const char *dmenucmd[]    = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont,
    "-nb", col_gray1, "-nf", col_gray4, "-sb", col_gray2, "-sf", col_accent,
    "-l", "20", NULL };
static const char *termcmd[]     = { "st", NULL };
static const char *browsercmd[]  = { "zen-browser", NULL };
static const char *filemgrcmd[]  = { "st", "-e", "lf", NULL };
static const char *telegramcmd[] = { "telegram-desktop", NULL };
static const char *steamcmd[]    = { "steam", NULL };
static const char *screenshot[]  = { "scrot", "-s", "/tmp/screenshot_%Y%m%d_%H%M%S.png", NULL };

static const char *vol_up[]      = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *vol_down[]    = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *vol_mute[]    = { "pactl", "set-sink-mute",   "@DEFAULT_SINK@", "toggle", NULL };

static const char *bri_up[]      = { "brightnessctl", "set", "+10%", NULL };
static const char *bri_down[]    = { "brightnessctl", "set", "10%-", NULL };

#include <X11/XF86keysym.h>

static const Key keys[] = {
    /* modifier                     key                       function        argument */

    /* Запуск программ */
    { MODKEY,                       XK_d,                     spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return,                spawn,          {.v = termcmd } },
    { MODKEY,                       XK_w,                     spawn,          {.v = browsercmd } },
    { MODKEY,                       XK_e,                     spawn,          {.v = filemgrcmd } },
    { MODKEY,                       XK_t,                     spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,             XK_s,                     spawn,          {.v = steamcmd } },
    { 0,                            XK_Print,                 spawn,          {.v = screenshot } },

    /* Громкость */
    { 0, XF86XK_AudioRaiseVolume,                            spawn,          {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume,                            spawn,          {.v = vol_down } },
    { 0, XF86XK_AudioMute,                                   spawn,          {.v = vol_mute } },

    /* Яркость */
    { 0, XF86XK_MonBrightnessUp,                             spawn,          {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown,                           spawn,          {.v = bri_down } },

    /* Управление окнами */
    { MODKEY,                       XK_j,                     focusstack,     {.i = +1 } },
    { MODKEY,                       XK_k,                     focusstack,     {.i = -1 } },
    { MODKEY,                       XK_h,                     setmfact,       {.f = -0.05} },
    { MODKEY,                       XK_l,                     setmfact,       {.f = +0.05} },
    { MODKEY,                       XK_i,                     incnmaster,     {.i = +1 } },
    { MODKEY|ShiftMask,             XK_i,                     incnmaster,     {.i = -1 } },
    { MODKEY|ShiftMask,             XK_Return,                zoom,           {0} },
    { MODKEY,                       XK_Tab,                   view,           {0} },

    /* Закрытие / выход */
    { MODKEY|ShiftMask,             XK_q,                     killclient,     {0} },
    { MODKEY|ControlMask|ShiftMask, XK_q,                     quit,           {0} },

    /* Раскладки */
    { MODKEY,                       XK_f,                     setlayout,      {.v = &layouts[0]} },
    { MODKEY|ShiftMask,             XK_f,                     setlayout,      {.v = &layouts[1]} },
    { MODKEY,                       XK_m,                     setlayout,      {.v = &layouts[2]} },
    { MODKEY,                       XK_space,                 setlayout,      {0} },
    { MODKEY|ShiftMask,             XK_space,                 togglefloating, {0} },

    /* Бар */
    { MODKEY,                       XK_b,                     togglebar,      {0} },

    /* Мониторы */
    { MODKEY,                       XK_comma,                 focusmon,       {.i = -1 } },
    { MODKEY,                       XK_period,                focusmon,       {.i = +1 } },
    { MODKEY|ShiftMask,             XK_comma,                 tagmon,         {.i = -1 } },
    { MODKEY|ShiftMask,             XK_period,                tagmon,         {.i = +1 } },

    /* Все теги */
    { MODKEY,                       XK_0,                     view,           {.ui = ~0 } },
    { MODKEY|ShiftMask,             XK_0,                     tag,            {.ui = ~0 } },

    /* Теги 1-9 */
    TAGKEYS(                        XK_1,                                     0)
    TAGKEYS(                        XK_2,                                     1)
    TAGKEYS(                        XK_3,                                     2)
    TAGKEYS(                        XK_4,                                     3)
    TAGKEYS(                        XK_5,                                     4)
    TAGKEYS(                        XK_6,                                     5)
    TAGKEYS(                        XK_7,                                     6)
    TAGKEYS(                        XK_8,                                     7)
    TAGKEYS(                        XK_9,                                     8)
};

static const Button buttons[] = {
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
    log "DWM успешно установлен"
    cd ~/suckless
}

# ===================== СБОРКА ST =====================
build_st() {
    log "Загрузка и сборка st (терминал)..."
    cd ~/suckless

    rm -rf st
    wget -qO st.tar.gz https://dl.suckless.org/st/st-0.9.2.tar.gz || \
    curl -sLo st.tar.gz https://dl.suckless.org/st/st-0.9.2.tar.gz

    tar -xzf st.tar.gz
    mv st-0.9.2 st
    rm st.tar.gz

    cd st
    sed -i 's/static char \*font = .*/static char *font = "JetBrains Mono:pixelsize=16:antialias=true:autohint=true";/' config.def.h
    sed -i 's/static int borderpx.*/static int borderpx = 12;/' config.def.h

    cp config.def.h config.h
    sudo make clean install
    log "st успешно установлен"
    cd ~/suckless
}

# ===================== СБОРКА DMENU =====================
build_dmenu() {
    log "Загрузка и сборка dmenu..."
    cd ~/suckless

    rm -rf dmenu
    wget -qO dmenu.tar.gz https://dl.suckless.org/tools/dmenu-5.3.tar.gz || \
    curl -sLo dmenu.tar.gz https://dl.suckless.org/tools/dmenu-5.3.tar.gz

    tar -xzf dmenu.tar.gz
    mv dmenu-5.3 dmenu
    rm dmenu.tar.gz

    cd dmenu
    sed -i 's/static const char \*fonts\[\] = {.*/static const char *fonts[] = { "JetBrains Mono:size=11" };/' config.def.h
    sed -i 's/\[SchemeNorm\] = .*/[SchemeNorm] = { "#b0b0b0", "#0a0a0a" },/' config.def.h
    sed -i 's/\[SchemeSel\] = .*/[SchemeSel]  = { "#ffffff", "#1a1a1a" },/' config.def.h
    sed -i 's/\[SchemeOut\] = .*/[SchemeOut]  = { "#000000", "#3a3a3a" },/' config.def.h
    sed -i 's/static unsigned int lines.*/static unsigned int lines = 20;/' config.def.h

    cp config.def.h config.h
    sudo make clean install
    log "dmenu успешно установлен"
    cd ~/suckless
}

# ===================== СТАТУС-БАР =====================
create_statusbar() {
    log "Создание скрипта статус-бара..."

    cat > ~/suckless/dwm-statusbar.sh << 'STATUSBAR'
#!/bin/bash
# DWM Status Bar — Монохромный

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

setxkbmap -layout us,ru -option grp:alt_shift_toggle &
xsetroot -cursor_name left_ptr &
picom --config ~/.config/picom/picom.conf -b 2>/dev/null &
xsetroot -solid "#0a0a0a" &
dunst &
lxsession &
~/suckless/dwm-statusbar.sh &

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
backend = "xrender";
shadow = true;
shadow-radius = 12;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.6;
shadow-color = "#000000";

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
    frame_width = 2
    frame_color = "#3a3a3a"
    font = JetBrains Mono 10
    corner_radius = 0

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

# ===================== LF =====================
create_lf_config() {
    log "Создание конфига lf..."

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

    log "lf настроен"
}

# ===================== GTK ТЕМА =====================
create_gtk_theme() {
    log "Настройка тёмной GTK темы..."

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

    log "GTK тема настроена"
}

# ===================== СЕССИЯ DWM =====================
create_session() {
    log "Создание файла сессии DWM..."

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
║  Super + Enter        — Терминал (st)                        ║
║  Super + D            — Меню запуска (dmenu)                 ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — Файловый менеджер (lf)               ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Print Screen         — Скриншот (выделение)                 ║
║                                                              ║
║  УПРАВЛЕНИЕ ОКНАМИ                                           ║
║  Super + J/K          — Переключение между окнами            ║
║  Super + H/L          — Изменение размера окон               ║
║  Super + Shift+Enter  — Сделать главным (master)             ║
║  Super + Shift + Q    — Закрыть окно                         ║
║  Super + Shift+Space  — Плавающий режим                      ║
║  Super + F            — Tiling layout                        ║
║  Super + Shift + F    — Floating layout                      ║
║  Super + M            — Monocle (полный экран)               ║
║  Super + B            — Скрыть/показать панель               ║
║                                                              ║
║  РАБОЧИЕ СТОЛЫ                                               ║
║  Super + 1-9          — Переключить рабочий стол             ║
║  Super + Shift + 1-9  — Перенести окно на стол               ║
║                                                              ║
║  СИСТЕМА                                                     ║
║  Ctrl+Super+Shift+Q   — Выход из DWM                         ║
║  Alt + Shift          — Смена языка (US/RU)                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
CHEAT

    log "Шпаргалка: ~/dwm-keybinds.txt"
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Monochrome Setup — CachyOS / Arch     ║${NC}"
    echo -e "${CYAN}║   Версия 3.0 (Стабильная сборка)            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
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
    create_session
    create_cheatsheet

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Запуск:"
    echo "  Display Manager → выберите сессию 'DWM'"
    echo "  Либо из TTY: startx"
    echo ""
}

main "$@"
