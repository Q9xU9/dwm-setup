#!/bin/bash
# install.sh — Полная установка DWM окружения на CachyOS/Arch
# Версия 5.0 — Обход блокировок через Gitee, Codeberg и Wayback Machine

set -e

# Полностью отключаем любые запросы паролей от Git в терминале
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
    log "Обновление системных баз данных pacman..."
    sudo pacman -Syu --noconfirm

    log "Установка основных программ и библиотек..."
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
        log "Установка yay (для AUR пакетов)..."
        cd /tmp
        rm -rf yay
        git clone --depth 1 https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ~
    else
        log "yay уже установлен"
    fi
}

# ===================== AUR ПАКЕТЫ =====================
install_aur_packages() {
    log "Установка приложений из AUR..."

    # Устанавливаем Zen Browser (мягкая установка, не уронит скрипт при ошибке)
    info "Установка Zen Browser..."
    yay -S --needed --noconfirm zen-browser-bin || \
    yay -S --needed --noconfirm zen-browser || \
    warn "Не удалось установить Zen Browser из AUR, установите его позже вручную."

    # Telegram
    info "Установка Telegram..."
    yay -S --needed --noconfirm telegram-desktop || \
        sudo pacman -S --needed --noconfirm telegram-desktop

    # Proton CachyOS (если не найдет — не страшно, Steam сам скачает Proton-GE)
    info "Установка Proton..."
    yay -S --needed --noconfirm proton-cachyos-bin 2>/dev/null || \
    yay -S --needed --noconfirm proton-cachyos 2>/dev/null || \
    yay -S --needed --noconfirm proton-ge-custom-bin 2>/dev/null || \
        warn "Proton CachyOS не найден, вы сможете установить его внутри самого Steam."
}

# ===================== УМНЫЙ ЗАГРУЗЧИК (БЕЗ БЛОКИРОВОК) =====================
download_tool() {
    local name=$1
    local gitee_url=$2
    local codeberg_url=$3
    local archive_url=$4

    log "Загрузка исходного кода для $name..."
    mkdir -p ~/suckless
    cd ~/suckless
    rm -rf "$name" "${name}.tar.gz"

    # Вариант 1: Gitee (Китайское супер-быстрое зеркало)
    info "Пробуем скачать с Gitee (быстрый запуск)..."
    if git clone --depth 1 "$gitee_url" "$name" 2>/dev/null; then
        log "$name успешно загружен с Gitee!"
        return 0
    fi

    # Вариант 2: Codeberg (Европейский независимый хостинг)
    warn "Gitee недоступен. Пробуем Codeberg..."
    if git clone --depth 1 "$codeberg_url" "$name" 2>/dev/null; then
        log "$name успешно загружен с Codeberg!"
        return 0
    fi

    # Вариант 3: Wayback Machine (Архив интернета — 100% стабильность)
    warn "Git-репозитории недоступны. Скачиваем стабильный архив из Wayback Machine..."
    if wget --timeout=10 -qO "${name}.tar.gz" "$archive_url" || curl -L --connect-timeout 10 -o "${name}.tar.gz" "$archive_url"; then
        tar -xzf "${name}.tar.gz"
        # Переименовываем распакованную папку в простое имя (например dwm-6.5 -> dwm)
        local extracted_dir
        extracted_dir=$(tar -tf "${name}.tar.gz" | head -1 | cut -f1 -d"/")
        mv "$extracted_dir" "$name"
        rm "${name}.tar.gz"
        log "$name успешно загружен из Архива Интернета!"
        return 0
    fi

    err "Не удалось загрузить $name. Проверьте подключение к интернету или DNS!"
}

# ===================== СБОРКА DWM =====================
build_dwm() {
    download_tool "dwm" \
        "https://gitee.com/mirrors/dwm.git" \
        "https://codeberg.org/gergelylaba/dwm.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/dwm/dwm-6.5.tar.gz"

    cd ~/suckless/dwm

    # Записываем наш монохромный config.h
    cat > config.h << 'DWMCONFIG'
/* ============================================================
 *  DWM config.h — Монохромная тема
 * ============================================================ */

static const unsigned int borderpx  = 2;
static const unsigned int snap      = 16;
static const int showbar            = 1;
static const int topbar             = 1;
static const char *fonts[]          = { "JetBrains Mono:size=11", "Font Awesome 6 Free:size=11" };
static const char dmenufont[]       = "JetBrains Mono:size=11";

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
    [SchemeNorm]   = { col_gray4,  col_gray1,  col_border   },
    [SchemeSel]    = { col_accent, col_gray2,  col_border_sel },
};

static const char *tags[] = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" };

static const Rule rules[] = {
    { "Steam",            NULL,     NULL,  1 << 3,    1,          -1 },
    { "TelegramDesktop",  NULL,     NULL,  1 << 2,    0,          -1 },
    { "Gimp",             NULL,     NULL,  0,         1,          -1 },
    { "pavucontrol",      NULL,     NULL,  0,         1,          -1 },
};

static const float mfact     = 0.55;
static const int nmaster     = 1;
static const int resizehints = 0;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
    { "[]=",   tile },
    { "><>",   NULL },
    { "[M]",   monocle },
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
    { MODKEY,                       XK_d,                     spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return,                spawn,          {.v = termcmd } },
    { MODKEY,                       XK_w,                     spawn,          {.v = browsercmd } },
    { MODKEY,                       XK_e,                     spawn,          {.v = filemgrcmd } },
    { MODKEY,                       XK_t,                     spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,             XK_s,                     spawn,          {.v = steamcmd } },
    { 0,                            XK_Print,                 spawn,          {.v = screenshot } },

    { 0, XF86XK_AudioRaiseVolume,                            spawn,          {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume,                            spawn,          {.v = vol_down } },
    { 0, XF86XK_AudioMute,                                   spawn,          {.v = vol_mute } },

    { 0, XF86XK_MonBrightnessUp,                             spawn,          {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown,                           spawn,          {.v = bri_down } },

    { MODKEY,                       XK_j,                     focusstack,     {.i = +1 } },
    { MODKEY,                       XK_k,                     focusstack,     {.i = -1 } },
    { MODKEY,                       XK_h,                     setmfact,       {.f = -0.05} },
    { MODKEY,                       XK_l,                     setmfact,       {.f = +0.05} },
    { MODKEY,                       XK_i,                     incnmaster,     {.i = +1 } },
    { MODKEY|ShiftMask,             XK_i,                     incnmaster,     {.i = -1 } },
    { MODKEY|ShiftMask,             XK_Return,                zoom,           {0} },
    { MODKEY,                       XK_Tab,                   view,           {0} },

    { MODKEY|ShiftMask,             XK_q,                     killclient,     {0} },
    { MODKEY|ControlMask|ShiftMask, XK_q,                     quit,           {0} },

    { MODKEY,                       XK_f,                     setlayout,      {.v = &layouts[0]} },
    { MODKEY|ShiftMask,             XK_f,                     setlayout,      {.v = &layouts[1]} },
    { MODKEY,                       XK_m,                     setlayout,      {.v = &layouts[2]} },
    { MODKEY,                       XK_space,                 setlayout,      {0} },
    { MODKEY|ShiftMask,             XK_space,                 togglefloating, {0} },

    { MODKEY,                       XK_b,                     togglebar,      {0} },

    { MODKEY,                       XK_comma,                 focusmon,       {.i = -1 } },
    { MODKEY,                       XK_period,                focusmon,       {.i = +1 } },
    { MODKEY|ShiftMask,             XK_comma,                 tagmon,         {.i = -1 } },
    { MODKEY|ShiftMask,             XK_period,                tagmon,         {.i = +1 } },

    { MODKEY,                       XK_0,                     view,           {.ui = ~0 } },
    { MODKEY|ShiftMask,             XK_0,                     tag,            {.ui = ~0 } },

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

    sudo make clean install
    log "DWM успешно скомпилирован и установлен!"
    cd ~/suckless
}

# ===================== СБОРКА ST =====================
build_st() {
    download_tool "st" \
        "https://gitee.com/mirrors/st.git" \
        "https://codeberg.org/dnkl/st.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/st/st-0.9.2.tar.gz"

    cd ~/suckless/st
    sed -i 's/static char \*font = .*/static char *font = "JetBrains Mono:pixelsize=16:antialias=true:autohint=true";/' config.def.h
    sed -i 's/static int borderpx.*/static int borderpx = 12;/' config.def.h

    cp config.def.h config.h
    sudo make clean install
    log "st успешно скомпилирован и установлен!"
    cd ~/suckless
}

# ===================== СБОРКА DMENU =====================
build_dmenu() {
    download_tool "dmenu" \
        "https://gitee.com/mirrors/dmenu.git" \
        "https://codeberg.org/gergelylaba/dmenu.git" \
        "https://web.archive.org/web/20240401000000/https://dl.suckless.org/tools/dmenu-5.3.tar.gz"

    cd ~/suckless/dmenu
    sed -i 's/static const char \*fonts\[\] = {.*/static const char *fonts[] = { "JetBrains Mono:size=11" };/' config.def.h
    sed -i 's/\[SchemeNorm\] = .*/[SchemeNorm] = { "#b0b0b0", "#0a0a0a" },/' config.def.h
    sed -i 's/\[SchemeSel\] = .*/[SchemeSel]  = { "#ffffff", "#1a1a1a" },/' config.def.h
    sed -i 's/\[SchemeOut\] = .*/[SchemeOut]  = { "#000000", "#3a3a3a" },/' config.def.h
    sed -i 's/static unsigned int lines.*/static unsigned int lines = 20;/' config.def.h

    cp config.def.h config.h
    sudo make clean install
    log "dmenu успешно скомпилирован и установлен!"
    cd ~/suckless
}

# ===================== СТАТУС-БАР =====================
create_statusbar() {
    log "Создание скрипта статус-бара..."

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

# ===================== SPRAVKA =====================
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
    echo -e "${CYAN}║   Версия 5.0 (Максимальный обход блоков)    ║${NC}"
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
    info "Для запуска DWM перезагрузите ПК и выберите сессию 'DWM'."
    echo ""
}

main "$@"
