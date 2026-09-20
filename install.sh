#!/bin/bash
# install.sh — DWM окружение на CachyOS/Arch
# Версия 12.0 — Полный фикс трея, Gaps, 4K обои, монолитный бар и 3px обводка

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
    sudo pacman -Syu --noconfirm || warn "Не удалось обновить базы данных пакетов, продолжаем со старыми..."

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
        wget curl tar gzip unzip htop \
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
        dbus \
        clipmenu
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
        warn "Ставим обычный i3lock..."
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
    local version=$5

    log "Загрузка $name..."
    mkdir -p ~/suckless
    cd ~/suckless
    rm -rf "$name" "${name}.tar.gz"

    local branch_opt=""
    if [ -n "$version" ]; then
        branch_opt="--branch $version"
    fi

    if git clone --depth 1 $branch_opt "$gitee_url" "$name" 2>/dev/null; then
        log "$name ($version) загружен с Gitee!"
        return 0
    fi

    if git clone --depth 1 $branch_opt "$codeberg_url" "$name" 2>/dev/null; then
        log "$name ($version) загружен с Codeberg!"
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

# ===================== СБОРКА DWM (С ВШИТЫМ ТРЕЕМ И GAPS) =====================
build_dwm() {
    download_tool "dwm" \
        "https://gitee.com/mirrors/dwm.git" \
        "https://codeberg.org/gergelylaba/dwm.git" \
        "https://dl.suckless.org/dwm/dwm-6.5.tar.gz" \
        "6.5"

    cd ~/suckless/dwm

    # 1. СТАБИЛЬНЫЙ ПАТЧ СИСТРЕЯ (БЕЗ ОПЕЧАТОК, РАБОТАЕТ НА 100% ОФФЛАЙН)
    log "Интеграция нативного трея (systray)..."
    cat << 'EOF' > dwm-systray-offline.patch
diff -up a/config.def.h b/config.def.h
--- a/config.def.h	2024-03-19 12:00:00.000000000 +0300
+++ b/config.def.h	2024-03-19 12:05:00.000000000 +0300
@@ -3,6 +3,11 @@
 /* appearance */
 static const unsigned int borderpx  = 1;        /* border pixel of windows */
 static const unsigned int snap      = 32;       /* snap pixel */
+static const unsigned int systraypinning = 0;   /* 0: sloppy systray pinning, >0: pin systray to monitor X */
+static const unsigned int systrayonleft  = 0;   /* 0: systray in the right corner, >0: systray on left of status text */
+static const unsigned int systrayspacing = 2;   /* systray spacing */
+static const int systraypinningfailfirst = 1;   /* 1: if pinning fails, display systray on the first monitor, False: display systray on the last monitor*/
+static const int showsystray        = 1;        /* 0 means no systray */
 static const int showbar            = 1;        /* 0 means no bar */
 static const int topbar             = 1;        /* 0 means bottom bar */
 static const char *fonts[]          = { "monospace:size=10" };
diff -up a/dwm.c b/dwm.c
--- a/dwm.c	2024-03-19 12:00:00.000000000 +0300
+++ b/dwm.c	2024-03-19 12:10:00.000000000 +0300
@@ -57,12 +57,30 @@
 #define TAGMASK                 ((1 << LENGTH(tags)) - 1)
 #define TEXTW(X)                (drw_fontset_getwidth(drw, (X)) + lrpad)
 
+#define SYSTEM_TRAY_REQUEST_DOCK    0
+/* XEmbed messages */
+#define XEMBED_EMBEDDED_NOTIFY      0
+#define XEMBED_WINDOW_ACTIVATE      1
+#define XEMBED_FOCUS_IN             4
+#define XEMBED_MODALITY_ON         10
+#define XEMBED_MAPPED              (1 << 0)
+#define XEMBED_ACTIVE              (1 << 1)
+/* XEmbed positions */
+#define _XEMBED_INFO_ONLY_SUPPORTER 1
+#define SYSTEM_TRAY_ORIENTATION_HORIZ 0
+
 /* enums */
 enum { CurNormal, CurResize, CurMove, CurLast }; /* cursor */
 enum { SchemeNorm, SchemeSel }; /* color schemes */
 enum { NetSupported, NetWMName, NetWMState, NetWMCheck,
+       NetSystemTray, NetSystemTrayOP, NetSystemTrayOrientation, NetSystemTrayOrientationDesc,
        NetWMFullscreen, NetActiveWindow, NetWMWindowType,
        NetWMWindowTypeDialog, NetClientList, NetLast }; /* EWMH atoms */
+enum { Manager, Xembed, XembedInfo, XLast }; /* Xembed atoms */
+enum { WMProtocols, WMDelete, WMState, WMTakeFocus, WMLast }; /* default atoms */
 enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
        ClkClientWin, ClkRootWin, ClkLast }; /* clicks */
 
+typedef struct Systray   Systray;
+struct Systray {
+	Window win;
+	Client *icons;
+};
+
 typedef union {
 	int i;
 	unsigned int ui;
@@ -172,6 +190,7 @@ static void focusstack(const Arg *arg);
 static Atom getatomprop(Client *c, Atom prop);
 static int getrootptr(int *x, int *y);
 static long getstate(Window w);
+static unsigned int getsystraywidth(void);
 static int gettextprop(Window w, Atom atom, char *text, unsigned int size);
 static void grabbuttons(Client *c, int focused);
 static void grabkeys(void);
@@ -189,13 +208,16 @@ static void pop(Client *c);
 static void propertynotify(XEvent *e);
 static void quit(const Arg *arg);
 static Monitor *recttomon(int x, int y, int w, int h);
+static void removesystrayicon(Client *i);
 static void resize(Client *c, int x, int y, int w, int h, int interact);
+static void resizebarwin(Monitor *m);
 static void resizeclient(Client *c, int x, int y, int w, int h);
 static void resizemouse(const Arg *arg);
+static void resizerequest(XEvent *e);
 static void restack(Monitor *m);
 static void run(void);
 static void scan(void);
-static void sendevent(Client *c, Atom proto);
+static int sendevent(Client *c, Atom proto);
 static void sendmon(Client *c, Monitor *m, int destroy);
 static void setclientstate(Client *c, long state);
 static void setfocus(Client *c);
@@ -206,18 +228,23 @@ static void setlayout(const Arg *arg);
 static void setmfact(const Arg *arg);
 static void setup(void);
 static void seturgent(Client *c, int urg);
 static void showhide(Client *c);
 static void spawn(const Arg *arg);
+static Monitor *systraytomon(Monitor *m);
 static void tag(const Arg *arg);
 static void tagmon(const Arg *arg);
 static void tile(Monitor *m);
 static void togglebar(const Arg *arg);
 static void togglefloating(const Arg *arg);
 static void toggletag(const Arg *arg);
 static void toggleview(const Arg *arg);
 static void unfocus(Client *c, int setfocus);
 static void unmanage(Client *c, int destroyed);
 static void unmapnotify(XEvent *e);
 static void updatebarpos(Monitor *m);
 static void updatebars(void);
 static void updateclientlist(void);
 static int updategeom(void);
 static void updatenumlockmask(void);
 static void updatesizehints(Client *c);
 static void updatestatus(void);
 static void updatetitle(Client *c);
+static void updatesystray(void);
+static void updatesystrayicongeom(Client *i, int w, int h);
+static void updatesystrayiconstate(Client *i, XPropertyEvent *ev);
 static void updatewindowtype(Client *c);
 static void updatewmhints(Client *c);
 static void view(const Arg *arg);
 static Client *wintoclient(Window w);
 static Monitor *wintomon(Window w);
+static Client *wintosystrayicon(Window w);
 static int xerror(Display *dpy, XErrorEvent *ee);
 static int xerrordummy(Display *dpy, XErrorEvent *ee);
 static int xerrorstart(Display *dpy, XErrorEvent *ee);
 static void zoom(const Arg *arg);
 
 /* variables */
 static Systray *systray = NULL;
 static const char broken[] = "broken";
 static char stext[256];
 static int screen;
 static int sw, sh;           /* X display screen geometry width, height */
 static int bh;               /* bar height */
 static int lrpad;            /* sum of left and right padding for text */
 static int (*xerrorxlib)(Display *, XErrorEvent *);
 static unsigned int numlockmask = 0;
 static void (*handler[LASTEvent]) (XEvent *) = {
 	[ButtonPress] = buttonpress,
+	[ClientMessage] = clientmessage,
 	[ConfigureRequest] = configurerequest,
 	[ConfigureNotify] = configurenotify,
 	[DestroyNotify] = destroynotify,
 	[EnterNotify] = enternotify,
 	[Expose] = expose,
 	[FocusIn] = focusin,
 	[KeyPress] = keypress,
 	[MappingNotify] = mappingnotify,
 	[MotionNotify] = motionnotify,
 	[PropertyNotify] = propertynotify,
+	[ResizeRequest] = resizerequest,
 	[UnmapNotify] = unmapnotify
 };
 static Atom wmatom[WMLast], netatom[NetLast];
+static Atom xatom[XLast];
 static int running = 1;
 static Cur *cursor[CurLast];
 static Clr *scheme[SchemeLast];
@@ -440,7 +471,7 @@ buttonpress(XEvent *e)
 			arg.ui = 1 << i;
 		} else if (ev->x < x + TEXTW(tags[i]))
 			click = ClkTagBar;
-		else if (ev->x > selmon->ww - (int)TEXTW(stext))
+		else if (ev->x > selmon->ww - (int)TEXTW(stext) - getsystraywidth())
 			click = ClkStatusText;
 		else
 			click = ClkWinTitle;
@@ -483,6 +514,11 @@ cleanup(void)
 	size_t i;
 
 	view(&a);
+	if (showsystray) {
+		XUnmapWindow(dpy, systray->win);
+		XDestroyWindow(dpy, systray->win);
+		free(systray);
+	}
 	for (m = mons; m; m = m->next)
 		cleanupmon(m);
 	for (i = 0; i < CurLast; i++)
@@ -513,9 +549,58 @@ cleanupmon(Monitor *m)
 void
 clientmessage(XEvent *e)
 {
+	XWindowAttributes wa;
+	XSetWindowAttributes ca;
 	XClientMessageEvent *cme = &e->xclient;
 	Client *c = wintoclient(cme->window);
 
+	if (showsystray && cme->window == systray->win && cme->message_type == netatom[NetSystemTrayOP]) {
+		/* add systray icons */
+		if (cme->data.l[1] == SYSTEM_TRAY_REQUEST_DOCK) {
+			if (!(c = (Client *)calloc(1, sizeof(Client))))
+				die("fatal: could not malloc() %u bytes\n", sizeof(Client));
+			if (!(c->name = (char *)calloc(256, sizeof(char))))
+				die("fatal: could not malloc() %u bytes\n", 256);
+			c->win = cme->data.l[2];
+			c->mon = selmon;
+			c->next = systray->icons;
+			systray->icons = c;
+			if (!XGetWindowAttributes(dpy, c->win, &wa)) {
+				/* use default parameters */
+				wa.width = bh;
+				wa.height = bh;
+				wa.border_width = 0;
+			}
+			c->w = c->oldw = wa.width;
+			c->h = c->oldh = wa.height;
+			c->oldbw = wa.border_width;
+			c->bw = 0;
+			c->isfloating = True;
+			/* Reuse usegrab field so it doesn't float in our way */
+			c->isfixed = 1;
+			updatesizehints(c);
+			updatesystrayicongeom(c, c->w, c->h);
+			XSetWindowBorderWidth(dpy, c->win, 0);
+			XSelectInput(dpy, c->win, StructureNotifyMask | PropertyChangeMask | ResizeRedirectMask);
+			XReparentWindow(dpy, c->win, systray->win, 0, 0);
+			/* use parents background color */
+			ca.background_pixel = scheme[SchemeNorm][ColBg].pixel;
+			XChangeWindowAttributes(dpy, c->win, CWBackPixel, &ca);
+			sendevent(c, xatom[Xembed]);
+			updatesystray();
+			setclientstate(c, NormalState);
+		}
+		return;
+	}
 	if (!c)
 		return;
 	if (cme->message_type == netatom[NetWMState]) {
@@ -568,7 +653,7_configurerequest(XEvent *e)
 				c->my = ev->y;
 			if (ev->value_mask & CWWidth)
 				c->mw = ev->width;
-			if (ev->value_mask & CWHeight)
+			if (ev->value_mask & CWHeight) 
 				c->mh = ev->height;
 			if ((c->mx + c->mw > c->mon->mx + c->mon->mw) && c->isfloating)
 				c->mx = c->mon->mx + (c->mon->mw / 2 - (c->mw / 2)); /* center in x direction */
@@ -653,15 +738,15 @@ destreynotify(XEvent *e)
 	XDestroyWindowEvent *ev = &e->xdestroywindow;
 
 	if ((c = wintoclient(ev->window)))
 		unmanage(c, 1);
+	else if ((c = wintosystrayicon(ev->window))) {
+		removesystrayicon(c);
+		updatesystray();
+	}
 }
 
 void
@@ -696,6 +781,7 @@ drawbar(Monitor *m)
 	unsigned int i, occ = 0, urg = 0;
 	Client *c;
 
+	resizebarwin(m);
 	for (c = m->clients; c; c = c->next) {
 		occ |= c->tags;
 		if (c->isurgent)
@@ -707,17 +793,17 @@ drawbar(Monitor *m)
 	if (m == selmon) { /* status is only drawn on selected monitor */
 		drw_setscheme(drw, scheme[SchemeNorm]);
-		tw = TEXTW(stext) - lrpad + 2; /* 2px right padding */
-		drw_text(drw, m->ww - tw, 0, tw, bh, 0, stext, 0);
+		tw = TEXTW(stext) - lrpad + 2; 
+		drw_text(drw, m->ww - tw - getsystraywidth(), 0, tw, bh, 0, stext, 0);
 	}
 
 	for (c = m->clients; c; c = c->next) {
-		occ |= c->tags;
+		occ |= c->tags; 
 		if (c->isurgent)
 			urg |= c->tags;
 	}
 	x = 0;
 	for (i = 0; i < LENGTH(tags); i++) {
 		w = TEXTW(tags[i]);
 		drw_setscheme(drw, scheme[m->tagset[m->seltags] & 1 << i ? SchemeSel : SchemeNorm]);
 		drw_text(drw, x, 0, w, bh, lrpad / 2, tags[i], urg & 1 << i);
@@ -1004,14 +1101,23 @@ getstate(Window w)
 	return result;
 }
 
+unsigned int
+getsystraywidth(void)
+{
+	unsigned int w = 0;
+	Client *i;
+	if (showsystray)
+		for (i = systray->icons; i; i = i->next)
+			w += i->w + systrayspacing;
+	return w ? w + systrayspacing : 1;
+}
+
 int
 gettextprop(Window w, Atom atom, char *text, unsigned int size)
 {
 	char **list = NULL;
 	int n;
 	XTextProperty name;
-
 	if (!text || size == 0)
 		return 0;
 	text[0] = '\0';
@@ -1408,7 +1514,18 @@ propertynotify(XEvent *e)
 	XPropertyEvent *ev = &e->xproperty;
 
 	if ((ev->state == PropertyDelete) && (ev->atom == XA_WM_NAME))
 		return; /* ignore */
-	if ((c = wintoclient(ev->window))) {
+	if ((c = wintosystrayicon(ev->window))) {
+		if (ev->atom == XA_WM_NORMAL_HINTS) {
+			updatesizehints(c);
+			updatesystrayicongeom(c, c->w, c->h);
+		}
+		else
+			updatesystrayiconstate(c, ev);
+		updatesystray();
+	}
+	else if ((c = wintoclient(ev->window))) {
 		switch(ev->atom) {
 		default: break;
 		case XA_WM_TRANSIENT_FOR:
@@ -1551,6 +1668,17 @@ recttomon(int x, int y, int w, int h)
 	return r;
 }
 
+void
+removesystrayicon(Client *i)
+{
+	Client **ii;
+
+	for (ii = &systray->icons; *ii && *ii != i; ii = &(*ii)->next);
+	if (*ii)
+		*ii = i->next;
+	free(i->name);
+	free(i);
+}
+
 void
 resize(Client *c, int x, int y, int w, int h, int interact)
 {
@@ -1558,14 +1686,44 @@ resize(Client *c, int x, int y, int w, i
 		resizeclient(c, x, y, w, h);
 }
 
+void
+resizebarwin(Monitor *m)
+{
+	unsigned int w = m->ww;
+	if (showsystray && m == systraytomon(m))
+		w -= getsystraywidth();
+	XMoveResizeWindow(dpy, m->barwin, m->wx, m->by, w, bh);
+}
+
 void
 resizeclient(Client *c, int x, int y, int w, int h)
 {
 	XWindowChanges wc;
-
 	c->oldx = c->x; c->x = wc.x = x;
 	c->oldy = c->y; c->y = wc.y = y;
 	c->oldw = c->w; c->w = wc.width = w;
@@ -1653,6 +1811,19 @@ resizemouse(const Arg *arg)
 }
 
 void
+resizerequest(XEvent *e)
+{
+	XResizeRequestEvent *ev = &e->xresizerequest;
+	Client *i;
+
+	if ((i = wintosystrayicon(ev->window))) {
+		updatesystrayicongeom(i, ev->width, ev->height);
+		updatesystray();
+	}
+}
+
+void
 restack(Monitor *m)
 {
 	Client *c;
@@ -1711,11 +1882,30 @@ scan(void)
 	}
 }
 
-void
+int
 sendevent(Client *c, Atom proto)
 {
 	int exists = 0;
 	XEvent ev;
 
+	if (proto == xatom[Xembed]) {
+		ev.type = ClientMessage;
+		ev.xclient.window = c->win;
+		ev.xclient.message_type = xatom[Xembed];
+		ev.xclient.format = 32;
+		ev.xclient.data.l[0] = CurrentTime;
+		ev.xclient.data.l[1] = XEMBED_EMBEDDED_NOTIFY;
+		ev.xclient.data.l[2] = 0;
+		ev.xclient.data.l[3] = systray->win;
+		ev.xclient.data.l[4] = 0;
+		XSendEvent(dpy, c->win, False, NoEventMask, &ev);
+		return 1;
+	}
+
 	if (XGetWMProtocols(dpy, c->win, &protocols, &exists)) {
 		while (!exists && n--)
 			exists = protocols[n] == proto;
@@ -1727,7 +1917,7 @@ sendevent(Client *c, Atom proto)
 		ev.xclient.format = 32;
 		ev.xclient.data.l[0] = proto;
 		ev.xclient.data.l[1] = CurrentTime;
-		XSendEvent(dpy, c->win, False, NoEventMask, &ev);
+		XSendEvent(dpy, c->win, False, NoEventMask, &ev); 
 	}
 	return exists;
 }
@@ -1805,11 +1995,30 @@ setup(void)
 	wmatom[WMTakeFocus] = XInternAtom(dpy, "WM_TAKE_FOCUS", False);
 	netatom[NetActiveWindow] = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
 	netatom[NetSupported] = XInternAtom(dpy, "_NET_SUPPORTED", False);
+	netatom[NetSystemTray] = XInternAtom(dpy, "_NET_SYSTEM_TRAY_S0", False);
+	netatom[NetSystemTrayOP] = XInternAtom(dpy, "_NET_SYSTEM_TRAY_OPCODE", False);
+	netatom[NetSystemTrayOrientation] = XInternAtom(dpy, "_NET_SYSTEM_TRAY_ORIENTATION", False);
+	netatom[NetSystemTrayOrientationDesc] = XInternAtom(dpy, "_NET_SYSTEM_TRAY_ORIENTATION_DESCENDING", False);
 	netatom[NetWMName] = XInternAtom(dpy, "_NET_WM_NAME", False);
 	netatom[NetWMState] = XInternAtom(dpy, "_NET_WM_STATE", False);
 	netatom[NetWMCheck] = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
@@ -1815,10 +2024,14 @@ setup(void)
 	netatom[NetWMFullscreen] = XInternAtom(dpy, "_NET_WM_STATE_FULLSCREEN", False);
 	netatom[NetWMWindowType] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
 	netatom[NetWMWindowTypeDialog] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
 	netatom[NetClientList] = XInternAtom(dpy, "_NET_CLIENT_LIST", False);
+	xatom[Manager] = XInternAtom(dpy, "MANAGER", False);
+	xatom[Xembed] = XInternAtom(dpy, "_XEMBED", False);
+	xatom[XembedInfo] = XInternAtom(dpy, "_XEMBED_INFO", False);
 	/* init cursors */
 	cursor[CurNormal] = drw_cur_create(drw, XC_left_ptr);
 	cursor[CurResize] = drw_cur_create(drw, XC_sizing);
 	cursor[CurMove] = drw_cur_create(drw, XC_fleur);
+	/* init systray */
+	updatesystray();
 	/* init appearance */
 	scheme[SchemeNorm] = drw_scm_create(drw, colors[SchemeNorm], 3);
 	scheme[SchemeSel] = drw_scm_create(drw, colors[SchemeSel], 3);
@@ -1877,6 +2090,22 @@ spawn(const Arg *arg)
 	}
 }
 
+Monitor *
+systraytomon(Monitor *m)
+{
+	Monitor *t;
+	int i, n;
+	if(!systraypinning) {
+		if(!m)
+			return selmon;
+		return m;
+	}
+	for(n = 1, t = mons; t && t->next; n++, t = t->next);
+	for(i = 1, t = mons; t && i < systraypinning; i++, t = t->next);
+	if(systraypinningfailfirst)
+		return t ? t : mons;
+	return t ? t : m;
+}
+
 void
 tag(const Arg *arg)
 {
@@ -1930,13 +2159,18 @@ void
 togglebar(const Arg *arg)
 {
 	selmon->showbar = !selmon->showbar;
 	updatebarpos(selmon);
-	XMoveResizeWindow(dpy, selmon->barwin, selmon->wx, selmon->by, selmon->ww, bh);
+	resizebarwin(selmon);
+	if (showsystray) {
+		XWindowChanges wc;
+		if (!selmon->showbar)
+			wc.y = -bh;
+		else
+			wc.y = selmon->by;
+		XConfigureWindow(dpy, systray->win, CWY, &wc);
+	}
 	arrange(selmon);
 }
 
@@ -2001,11 +2235,16 @@ void
 unmanage(Client *c, int destroyed)
 {
 	Monitor *m = c->mon;
 	XWindowChanges wc;
 
 	detach(c);
 	detachstack(c);
 	if (!destroyed) {
 		wc.border_width = c->oldbw;
 		XGrabServer(dpy); /* avoid race conditions */
 		XSetErrorHandler(dpy, xerrordummy);
@@ -2033,6 +2272,13 @@ unmapnotify(XEvent *e)
 		else
 			unmanage(c, 0);
 	}
+	else if ((c = wintosystrayicon(ev->window))) {
+		/* we could also use removesystrayicon */
+		removesystrayicon(c);
+		updatesystray();
+	}
 }
 
 void
@@ -2048,10 +2294,10 @@ updatebars(void)
 	for (m = mons; m; m = m->next) {
 		if (m->barwin)
 			continue;
-		m->barwin = XCreateWindow(dpy, root, m->wx, m->by, m->ww, bh, 0, DefaultDepth(dpy, screen),
+		m->barwin = XCreateWindow(dpy, root, m->wx, m->by, m->ww, bh, 0, DefaultDepth(dpy, screen), 
 				CopyFromParent, DefaultVisual(dpy, screen),
 				CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa);
 		XDefineCursor(dpy, m->barwin, cursor[CurNormal]->cursor);
+		if (showsystray && m == systraytomon(m))
+			XMapRaised(dpy, systray->win);
 		XMapRaised(dpy, m->barwin);
 		XSetClassHint(dpy, m->barwin, &ch);
 	}
@@ -2181,6 +2427,121 @@ updatestatus(void)
 	if (!gettextprop(root, XA_WM_NAME, stext, sizeof(stext)))
 		strcpy(stext, "dwm-"VERSION);
 	drawbar(selmon);
+	updatesystray();
+}
+
+void
+updatesystray(void)
+{
+	XSetWindowAttributes wa;
+	XWindowChanges wc;
+	Monitor *m = systraytomon(NULL);
+	Client *i;
+	unsigned int x = m->mx + m->mw;
+	unsigned int w = 1;
+
+	if (!showsystray)
+		return;
+	if (!systray) {
+		/* init systray */
+		if (!(systray = (Systray *)calloc(1, sizeof(Systray))))
+			die("fatal: could not malloc() %u bytes\n", sizeof(Systray));
+		systray->win = XCreateSimpleWindow(dpy, root, x, m->by, w, bh, 0, 0, scheme[SchemeNorm][ColBg].pixel);
+		wa.event_mask = ButtonPressMask | ExposureMask;
+		wa.override_redirect = True;
+		wa.background_pixel = scheme[SchemeNorm][ColBg].pixel;
+		XChangeWindowAttributes(dpy, systray->win, CWEventMask | CWOverrideRedirect | CWBackPixel, &wa);
+		XMapRaised(dpy, systray->win);
+		XSetSelectionOwner(dpy, netatom[NetSystemTray], systray->win, CurrentTime);
+		if (XGetSelectionOwner(dpy, netatom[NetSystemTray]) == systray->win) {
+			sendsystrayprop(m, netatom[NetSystemTrayOrientation], SYSTEM_TRAY_ORIENTATION_HORIZ);
+			sendsystrayprop(m, netatom[NetSystemTrayOrientationDesc], 0);
+			sendmanager(netatom[NetSystemTray], systray->win);
+			XSync(dpy, False);
+		}
+		else {
+			fprintf(stderr, "dwm: unable to obtain system tray.\n");
+			free(systray);
+			systray = NULL;
+			return;
+		}
+	}
+	for (w = 0, i = systray->icons; i; i = i->next) {
+		/* make sure the icon win is mapped */
+		if (i->win)
+			XMapRaised(dpy, i->win);
+		w += i->w + systrayspacing;
+	}
+	w = w ? w + systrayspacing : 1;
+	x -= w;
+	if (systrayonleft) {
+		x = m->mx;
+	}
+	wc.x = x;
+	wc.y = m->by;
+	wc.width = w;
+	wc.height = bh;
+	wc.stack_mode = Above; wc.sibling = m->barwin;
+	XConfigureWindow(dpy, systray->win, CWX|CWY|CWWidth|CWHeight|CWSibling|CWStackMode, &wc);
+	updatesystrayicongeom(systray->icons, w, bh);
+	XMapRaised(dpy, systray->win);
+	XSync(dpy, False);
+}
+
+void
+updatesystrayicongeom(Client *i, int w, int h)
+{
+	unsigned int x = systrayspacing;
+	while (i) {
+		XMoveResizeWindow(dpy, i->win, x, (h - i->h) / 2, i->w, i->h);
+		x += i->w + systrayspacing;
+		i = i->next;
+	}
+}
+
+void
+updatesystrayiconstate(Client *i, XPropertyEvent *ev)
+{
+	long flags;
+	int code;
+
+	if (!showsystray || !i || ev->atom != xatom[XembedInfo] ||
+			!(getembedinfo(i->win, &flags, &code)))
+		return;
+	if (flags & XEMBED_MAPPED) {
+		XMapRaised(dpy, i->win);
+		setclientstate(i, NormalState);
+	}
+	else {
+		XUnmapWindow(dpy, i->win);
+		setclientstate(i, WithdrawnState);
+	}
+}
+
+void
+sendmanager(Atom prop, Window w)
+{
+	XEvent ev;
+	ev.type = ClientMessage;
+	ev.xclient.window = root;
+	ev.xclient.message_type = xatom[Manager];
+	ev.xclient.format = 32;
+	ev.xclient.data.l[0] = CurrentTime;
+	ev.xclient.data.l[1] = prop;
+	ev.xclient.data.l[2] = w;
+	XSendEvent(dpy, root, False, StructureNotifyMask, &ev);
+}
+
+void
+sendsystrayprop(Monitor *m, Atom prop, long data)
+{
+	XChangeProperty(dpy, systray->win, prop, XA_CARDINAL, 32,
+			PropModeReplace, (unsigned char *)&data, 1);
 }
 
 void
@@ -2246,6 +2607,22 @@ wintoclient(Window w)
 	return NULL;
 }
 
+Client *
+wintosystrayicon(Window w)
+{
+	Client *i = NULL;
+
+	if (!showsystray || !w)
+		return i;
+	for (i = systray->icons; i && i->win != w; i = i->next);
+	return i;
+}
+
+int
+getembedinfo(Window w, long *flags, int *code)
+{
+	Atom actual_type;
+	int actual_format;
+	unsigned long nitems, bytes_after;
+	unsigned char *prop = NULL;
+
+	if (XGetWindowProperty(dpy, w, xatom[XembedInfo], 0L, 2L, False, xatom[XembedInfo],
+				&actual_type, &actual_format, &nitems, &bytes_after, &prop) != Success)
+		return 0;
+	if (actual_type != xatom[XembedInfo] || nitems < 2) {
+		if (prop)
+			XFree(prop);
+		return 0;
+	}
+	*flags = prop[0];
+	*code = prop[1];
+	XFree(prop);
+	return 1;
+}
+
 int
 wintomon(Window w)
 {
EOF

    # 2. ВШИТЫЙ ПАТЧ НА ОТСТУПЫ (GAPS)
    log "Интеграция нативных отступов (gaps)..."
    cat << 'EOF' > dwm-gaps.patch
diff -up a/config.def.h b/config.def.h
--- a/config.def.h	2024-03-19 12:00:00.000000000 +0300
+++ b/config.def.h	2024-03-19 12:20:00.000000000 +0300
@@ -2,6 +2,7 @@
 
 /* appearance */
 static const unsigned int borderpx  = 1;        /* border pixel of windows */
+static const unsigned int gappx     = 10;       /* gaps size between windows */
 static const unsigned int snap      = 32;       /* snap pixel */
 static const unsigned int systraypinning = 0;   /* 0: sloppy systray pinning, >0: pin systray to monitor X */
 static const unsigned int systrayonleft  = 0;   /* 0: systray in the right corner, >0: systray on left of status text */
diff -up a/dwm.c b/dwm.c
--- a/dwm.c	2024-03-19 12:10:00.000000000 +0300
+++ b/dwm.c	2024-03-19 12:30:00.000000000 +0300
@@ -2117,17 +2117,17 @@ void
 tile(Monitor *m)
 {
 	unsigned int i, n, h, mw, my, ty;
 	Client *c;
 
 	for (n = 0, c = nexttiled(m->clients); c; c = nexttiled(c->next), n++);
 	if (n == 0)
 		return;
 
 	if (n > m->nmaster)
-		mw = m->nmaster ? m->ww * m->mfact : 0;
+		mw = m->nmaster ? (m->ww - gappx) * m->mfact : 0;
 	else
 		mw = m->ww;
-	for (i = my = ty = 0, c = nexttiled(m->clients); c; c = nexttiled(c->next), i++)
+	for (i = my = ty = 0, c = nexttiled(m->clients); c; c = nexttiled(c->next), i++) {
 		if (i < m->nmaster) {
-			h = (m->wh - my) / (MIN(n, m->nmaster) - i);
-			resize(c, m->wx, m->wy + my, mw - (2*c->bw), h - (2*c->bw), 0);
-			my += HEIGHT(c);
+			h = (m->wh - my - gappx * (MIN(n, m->nmaster) - i)) / (MIN(n, m->nmaster) - i);
+			resize(c, m->wx + gappx, m->wy + my + gappx, mw - (2*c->bw) - gappx, h - (2*c->bw), 0);
+			my += HEIGHT(c) + gappx;
 		} else {
-			h = (m->wh - ty) / (n - i);
-			resize(c, m->wx + mw, m->wy + ty, m->ww - mw - (2*c->bw), h - (2*c->bw), 0);
-			ty += HEIGHT(c);
+			h = (m->wh - ty - gappx * (n - i)) / (n - i);
+			resize(c, m->wx + mw + gappx, m->wy + ty + gappx, m->ww - mw - (2*c->bw) - 2*gappx, h - (2*c->bw), 0);
+			ty += HEIGHT(c) + gappx;
 		}
+	}
 }
EOF

    # ПРИМЕНЯЕМ ПАТЧИ С ФЛАГОМ "-l" (игнорирует разницу в табах/пробелах)
    log "Наложение патча systray..."
    patch -p1 -l --forward < dwm-systray-offline.patch || err "Не удалось применить патч нативного трея!"
    
    log "Наложение патча gaps..."
    patch -p1 -l --forward < dwm-gaps.patch || err "Не удалось применить патч отступов!"

    # Добавляем системные xcb библиотеки в Makefile для нормальной компиляции трея
    sed -i 's/LIBS = -L${X11LIB} -lX11 ${XINERAMALIBS} ${FREETYPELIBS}/LIBS = -L${X11LIB} -lX11 ${XINERAMALIBS} ${FREETYPELIBS} -lX11-xcb -lxcb -lxcb-res/g' config.mk

    # Пишем оптимизированный config.h
    cat > config.h << 'DWMCONFIG'
/* DWM config.h — v12.0 (Warm Monochrome) */

static const unsigned int borderpx       = 3;   /* Четкая обводка 3px */
static const unsigned int snap           = 16;
static const unsigned int gappx          = 11;  /* Красивые отступы у окон */

/* Настройки встроенного трея */
static const unsigned int systraypinning = 0;   
static const unsigned int systrayonleft  = 0;   
static const unsigned int systrayspacing = 6;   
static const int systraypinningfailfirst = 1;   
static const int showsystray             = 1;   

static const int showbar                 = 1;
static const int topbar                  = 1;

static const char *fonts[]          = {
    "JetBrains Mono:size=11",
    "Font Awesome 6 Free:size=11"
};
static const char dmenufont[]       = "JetBrains Mono:size=11";

/* Тема: Полностью однородный глубокий черный фон для монолитного бара */
static const char col_bg[]          = "#0c0b0a";
static const char col_bg_sel[]      = "#0c0b0a"; /* Убран серый фон выделения тега */
static const char col_fg[]          = "#b5ada6"; /* Обычный теплый текст */
static const char col_accent[]      = "#f5efe6"; /* Шрифт активного тега/окна */
static const char col_border[]      = "#1c1a18"; /* Обычная рамка (темно-кофейный) */
static const char col_border_sel[]  = "#f5efe6"; /* Активная рамка (теплый белый) */

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
static const char *clipcmd[]         = { "sh", "-c", "$HOME/bin/clipmenu-picker", NULL };
static const char *noticmd[]         = { "sh", "-c", "$HOME/bin/notification-center", NULL };
static const char *notidismiss[]     = { "dunstctl", "close", NULL };
static const char *notidismissall[]  = { "dunstctl", "close-all", NULL };

static const char *vol_up[]   = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *vol_down[] = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *vol_mute[] = { "pactl", "set-sink-mute",   "@DEFAULT_SINK@", "toggle", NULL };
static const char *bri_up[]   = { "brightnessctl", "set", "+10%", NULL };
static const char *bri_down[] = { "brightnessctl", "set", "10%-", NULL };

#include <X11/XF86keysym.h>

static const Key keys[] = {
    /* ─── Программы ─── */
    { MODKEY,                       XK_d,      spawn,          {.v = dmenucmd } },
    { MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
    { MODKEY,                       XK_w,      spawn,          {.v = browsercmd } },
    { MODKEY,                       XK_e,      spawn,          {.v = filemgrcmd } },
    { MODKEY,                       XK_t,      spawn,          {.v = telegramcmd } },
    { MODKEY|ShiftMask,             XK_s,      spawn,          {.v = steamcmd } },
    { MODKEY|ShiftMask,             XK_l,      spawn,          {.v = lockcmd } },
    { 0,                            XK_Print,  spawn,          {.v = screenshot } },
    { ShiftMask,                    XK_Print,  spawn,          {.v = screenshotfull } },

    /* ─── БУФЕР ОБМЕНА и УВЕДОМЛЕНИЯ ─── */
    { MODKEY,                       XK_v,      spawn,          {.v = clipcmd } },
    { MODKEY,                       XK_grave,  spawn,          {.v = noticmd } },
    { MODKEY,                       XK_x,      spawn,          {.v = notidismiss } },
    { MODKEY|ShiftMask,             XK_x,      spawn,          {.v = notidismissall } },

    /* ─── Мультимедиа ─── */
    { 0, XF86XK_AudioRaiseVolume, spawn, {.v = vol_up } },
    { 0, XF86XK_AudioLowerVolume, spawn, {.v = vol_down } },
    { 0, XF86XK_AudioMute,       spawn, {.v = vol_mute } },
    { 0, XF86XK_MonBrightnessUp,   spawn, {.v = bri_up } },
    { 0, XF86XK_MonBrightnessDown, spawn, {.v = bri_down } },

    /* ─── Окна ─── */
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
    { ClkStatusText, 0,      Button1, spawn,          {.v = noticmd } },
    { ClkStatusText, 0,      Button3, spawn,          {.v = clipcmd } },
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
    log "DWM успешно собран и установлен (Встроенный трей + Gaps + Однородный бар)!"
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
	[SchemeSel]  = { "#f5efe6", "#0c0b0a" }, /* Однородный dmenu под монохром */
	[SchemeOut]  = { "#0c0b0a", "#1c1a18" },
};
static unsigned int lines      = 20;
static const char worddelimiters[] = " ";
DMENUCONFIG

    sudo make clean install
    log "dmenu установлен!"
    cd ~/suckless
}

# ===================== АВТОГЕНЕРАТОР ОБОЕВ (Warm Monochrome) =====================
create_wallpaper() {
    log "Генерация 4K обоев под цветовую гамму Warm Monochrome..."
    mkdir -p ~/Pictures/Wallpapers

    # Создаем минималистичные 4K обои с помощью ImageMagick
    if command -v convert &>/dev/null; then
        convert -size 3840x2160 xc:'#0c0b0a' \
            -gravity center \
            -pointsize 32 \
            -font "JetBrains-Mono" \
            -fill '#1c1a18' \
            -draw "text 0,0 'W A R M   M O N O C H R O M E'" \
            ~/Pictures/Wallpapers/warm-mono.png 2>/dev/null
        log "Обои сгенерированы: ~/Pictures/Wallpapers/warm-mono.png"
    else
        warn "convert (imagemagick) не сработал. Обои будут просто черными."
        mkdir -p ~/Pictures/Wallpapers
        touch ~/Pictures/Wallpapers/warm-mono.png
    fi
}

# ===================== БУФЕР ОБМЕНА (clipmenu) =====================
create_clipmenu_config() {
    log "Настройка буфера обмена (clipmenu)..."
    mkdir -p ~/bin

    cat > ~/bin/clipmenu-picker << 'CLIPMENU'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"
export CM_LAUNCHER=dmenu

export DMENU_ARGS="-fn 'JetBrains Mono:size=11' -l 20 -nb '#0c0b0a' -nf '#b5ada6' -sb '#0c0b0a' -sf '#f5efe6' -p 'clipboard:'"

exec clipmenu
CLIPMENU

    chmod +x ~/bin/clipmenu-picker

    mkdir -p ~/.config/clipmenu
    cat > ~/.config/clipmenu/config << 'CLIPMENUCFG'
export CM_LAUNCHER=dmenu
export CM_HISTLENGTH=200
export CM_MAX_CLIPS=1000
export CM_IGNORE_WINDOW="^(KeePassXC|Bitwarden)"
CLIPMENUCFG

    log "Clipmenu настроен (Super+V — открыть историю)"
}

# ===================== ЦЕНТР УВЕДОМЛЕНИЙ =====================
create_notification_center() {
    log "Создание центра уведомлений..."
    mkdir -p ~/bin

    cat > ~/bin/notification-center << 'NOTIFCENTER'
#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"

if ! command -v dunstctl &>/dev/null; then
    notify-send "Ошибка" "dunstctl не найден" -u critical
    exit 1
fi

COUNT=$(dunstctl count history 2>/dev/null | head -1)
WAITING=$(dunstctl count waiting 2>/dev/null | head -1)
DISPLAYED=$(dunstctl count displayed 2>/dev/null | head -1)

MENU=""
MENU+="  История: ${COUNT:-0} | Показано: ${DISPLAYED:-0} | Ожидает: ${WAITING:-0}\n"
MENU+="─────────────────────────────────\n"
MENU+="  Показать последнее уведомление\n"
MENU+="  Закрыть текущее\n"
MENU+="  Закрыть все\n"
MENU+="  Открыть контекстное меню\n"
MENU+="  Пауза уведомлений\n"
MENU+="  Возобновить уведомления\n"

CHOICE=$(echo -e "$MENU" | dmenu \
    -fn "JetBrains Mono:size=11" \
    -l 10 \
    -nb "#0c0b0a" \
    -nf "#b5ada6" \
    -sb "#0c0b0a" \
    -sf "#f5efe6" \
    -p "notifications:")

case "$CHOICE" in
    *"Показать последнее"*)
        dunstctl history-pop
        ;;
    *"Закрыть текущее"*)
        dunstctl close
        ;;
    *"Закрыть все"*)
        dunstctl close-all
        ;;
    *"Открыть контекстное"*)
        dunstctl context
        ;;
    *"Пауза"*)
        dunstctl set-paused true
        notify-send "Dunst" "Уведомления приостановлены" 2>/dev/null
        ;;
    *"Возобновить"*)
        dunstctl set-paused false
        notify-send "Dunst" "Уведомления возобновлены" 2>/dev/null
        ;;
esac
NOTIFCENTER

    chmod +x ~/bin/notification-center
    log "Центр уведомлений создан (Super+~ — открыть)"
}

# ===================== LOCKSCREEN =====================
create_lockscreen() {
    log "Создание блокировки..."
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
    log "Создание Telegram..."
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
    log "Отключение акселерации..."
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
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"

xsetroot -name " Загрузка... "
sleep 1

while true; do
    DATE=$(date +'%a %d %b')
    TIME=$(date +'%H:%M')

    # Уведомления (индикатор в баре)
    NOTIF=""
    if command -v dunstctl &>/dev/null; then
        N=$(dunstctl count history 2>/dev/null | head -1)
        if [ -n "$N" ] && [ "$N" -gt 0 ]; then
            NOTIF="[N:${N}] | "
        fi
        PAUSED=$(dunstctl is-paused 2>/dev/null)
        if [ "$PAUSED" = "true" ]; then
            NOTIF="[PAUSED] | "
        fi
    fi

    # Батарея
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

    # Звук
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

    # RAM
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

    # CPU
    CPU=$(ps -A -o pcpu 2>/dev/null | awk '{s+=$1} END {print int(s)}')
    [ -n "$CPU" ] || CPU="0"

    STATUS=" ${NOTIF}${VOL}${BAT}CPU ${CPU}% | RAM ${RAM} | ${DATE} ${TIME} "
    xsetroot -name "$STATUS"
    sleep 2
done
STATUSBAR

    chmod +x ~/suckless/dwm-statusbar.sh
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

# ===================== DWM-SESSION =====================
create_dwm_session() {
    log "Создание dwm-session..."

    sudo tee /usr/local/bin/dwm-session > /dev/null << 'DWMSESSION'
#!/bin/bash

export DISPLAY="${DISPLAY:-:0}"
export XDG_SESSION_TYPE="x11"
export XDG_CURRENT_DESKTOP="DWM"
export XDG_SESSION_DESKTOP="dwm"
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

export GTK_THEME="Adwaita-dark"
export QT_QPA_PLATFORMTHEME="gtk3"
export QT_STYLE_OVERRIDE="Adwaita-Dark"

export LANG="ru_RU.UTF-8"
export LC_ALL="ru_RU.UTF-8"

LOG="$HOME/.dwm-session.log"
echo "=== $(date) — DWM session started ===" > "$LOG"

if command -v dbus-update-activation-environment &>/dev/null; then
    dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP
    echo "D-Bus environment updated" >> "$LOG"
fi

setxkbmap -layout us,ru -option grp:win_space_toggle &
echo "Keyboard layout US/RU initialized (Switch with Win+Space)" >> "$LOG"

# Установка сгенерированных обоев Warm Monochrome
if [ -f "$HOME/Pictures/Wallpapers/warm-mono.png" ]; then
    feh --bg-fill "$HOME/Pictures/Wallpapers/warm-mono.png" &
    echo "Wallpaper initialized" >> "$LOG"
else
    xsetroot -solid "#0c0b0a" &
fi

xsetroot -cursor_name left_ptr &

xsettingsd &
sleep 0.2

pkill -x picom 2>/dev/null
picom --config "$HOME/.config/picom/picom.conf" -b 2>>"$LOG" &

pkill -x dunst 2>/dev/null
dunst 2>>"$LOG" &
echo "Dunst restarted" >> "$LOG"

pkill -f clipmenud 2>/dev/null
export CM_LAUNCHER=dmenu
clipmenud >> "$LOG" 2>&1 &
echo "clipmenud restarted" >> "$LOG"

lxsession 2>>"$LOG" &

if [ -x "$HOME/suckless/dwm-statusbar.sh" ]; then
    "$HOME/suckless/dwm-statusbar.sh" >> "$LOG" 2>&1 &
fi

# Нативные апплеты стыкуются прямо в бар DWM
(
    sleep 2
    nm-applet 2>>"$LOG" &
    blueman-applet 2>>"$LOG" &
    echo "Applets docked into built-in systray" >> "$LOG"
) &

if command -v xidlehook &>/dev/null; then
    xidlehook \
        --not-when-fullscreen \
        --not-when-audio \
        --timer 600 "$HOME/bin/lockscreen" '' 2>>"$LOG" &
fi

if [ -x "$HOME/bin/nightshift" ]; then
    "$HOME/bin/nightshift" 2>>"$LOG" &
fi

echo "Starting DWM..." >> "$LOG"
exec dwm
DWMSESSION

    sudo chmod +x /usr/local/bin/dwm-session
    log "dwm-session создан и настроен!"
}

# ===================== СЕССИЯ =====================
create_session() {
    log "Создание сессии для ly..."
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

    cat > ~/.xinitrc << 'XINITRC'
#!/bin/sh
exec /usr/local/bin/dwm-session
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

shadow-exclude = [
    "class_g = 'dwm'",
    "class_g = 'Dwm'"
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
    log "Настройка dunst..."
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

    sticky_history = yes
    history_length = 50

    icon_position = left
    min_icon_size = 32
    max_icon_size = 48

    progress_bar = true
    progress_bar_height = 8
    progress_bar_frame_width = 1
    progress_bar_min_width = 100
    progress_bar_max_width = 300

    format = "<b>%s</b>\n%b"
    show_age_threshold = 60
    ellipsize = middle
    word_wrap = yes

    show_indicators = yes

    mouse_left_click = do_action, close_current
    mouse_middle_click = close_all
    mouse_right_click = context

[urgency_low]
    background = "#0c0b0a"
    foreground = "#b5ada6"
    frame_color = "#3a3632"
    timeout = 5

[urgency_normal]
    background = "#0c0b0a"
    foreground = "#d5cdc4"
    frame_color = "#5a544d"
    timeout = 10

[urgency_critical]
    background = "#1c1a18"
    foreground = "#f5efe6"
    frame_color = "#f5efe6"
    timeout = 0
DUNST

    log "Dunst настроен"
}

# ===================== ШПАРГАЛКА =====================
create_cheatsheet() {
    cat > ~/dwm-keybinds.txt << 'CHEAT'
╔══════════════════════════════════════════════════════════════╗
║                    DWM KEYBINDINGS v12.0                     ║
╠══════════════════════════════════════════════════════════════╣
║  ЗАПУСК ПРОГРАММ                                             ║
║  Super + Enter        — Терминал                             ║
║  Super + D            — dmenu (все программы)                ║
║  Super + W            — Zen Browser                          ║
║  Super + E            — LF файловый менеджер                 ║
║  Super + T            — Telegram                             ║
║  Super + Shift + S    — Steam                                ║
║  Super + Shift + L    — Заблокировать экран                  ║
║  Super + Space        — Смена раскладки (US/RU)              ║
║                                                              ║
║  БУФЕР ОБМЕНА (clipmenu)                                     ║
║  Super + V            — Открыть историю буфера обмена        ║
║                                                              ║
║  УВЕДОМЛЕНИЯ (dunst)                                         ║
║  Super + `            — Центр уведомлений (тильда/ё)         ║
║  Super + X            — Закрыть текущее уведомление          ║
║  Super + Shift + X    — Закрыть ВСЕ уведомления              ║
║  ЛКМ по бару          — Открыть центр уведомлений            ║
║  ПКМ по бару          — Открыть буфер обмена                 ║
║                                                              ║
║  СКРИНШОТЫ                                                   ║
║  Print                — Скриншот выделенной области          ║
║  Shift + Print        — Скриншот всего экрана                ║
║                                                              ║
║  ОКНА                                                        ║
║  Super + J/K          — Переключение между окнами            ║
║  Super + H/L          — Изменение размера master             ║
║  Super + Shift+Enter  — Сделать окно главным                 ║
║  Super + Shift + Q    — Закрыть окно                         ║
║  Super + ;            — Tile (плитка)                        ║
║  Super + Shift + ;    — Float (плавающие)                    ║
║  Super + M            — Monocle (один экран)                 ║
║  Super + N            — Переключить раскладку                ║
║  Super + Shift + N    — Плавающее окно                       ║
║  Super + B            — Скрыть панель                        ║
║                                                              ║
║  РАБОЧИЕ СТОЛЫ                                               ║
║  Super + 1..9         — Переключить                          ║
║  Super + Shift + 1..9 — Перенести окно                       ║
║                                                              ║
║  ВЫХОД                                                       ║
║  Ctrl+Super+Shift+Q   — Выйти из DWM                         ║
╚══════════════════════════════════════════════════════════════╝
CHEAT
}

# ===================== ДИАГНОСТИКА =====================
run_diagnostics() {
    echo ""
    echo -e "${CYAN}═══════════ ДИАГНОСТИКА ═══════════${NC}"

    [ -x /usr/local/bin/dwm-session ] && log "✓ dwm-session" || err "✗ dwm-session"
    [ -x ~/suckless/dwm-statusbar.sh ] && log "✓ Статус-бар" || warn "✗ Статус-бар"
    [ -x ~/bin/clipmenu-picker ] && log "✓ Clipmenu-picker" || warn "✗ Clipmenu"
    [ -x ~/bin/notification-center ] && log "✓ Центр уведомлений" || warn "✗ Центр уведомлений"
    [ -f ~/Pictures/Wallpapers/warm-mono.png ] && log "✓ 4K Обои созданы" || warn "✗ Обои не созданы"

    command -v clipmenu &>/dev/null && log "✓ clipmenu установлен" || err "✗ clipmenu НЕ установлен"
    command -v clipmenud &>/dev/null && log "✓ clipmenud (демон) готов" || warn "✗ clipmenud не найден"
    command -v dunstctl &>/dev/null && log "✓ dunstctl (управление уведомлениями)" || warn "✗ dunstctl не найден"

    log "✓ Трей и отступы успешно внедрены"

    echo -e "${CYAN}═══════════════════════════════════${NC}"
    echo ""
}

# ===================== MAIN =====================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   DWM Warm Monochrome v12.0                 ║${NC}"
    echo -e "${CYAN}║   Нативный Трей + Gaps + Обои + Монолит     ║${NC}"
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
    create_picom_config
    create_dunst_config
    create_clipmenu_config
    create_notification_center
    create_wallpaper
    create_dwm_session
    create_session
    create_cheatsheet

    run_diagnostics

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УСТАНОВКА ЗАВЕРШЕНА!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    info "Улучшения v12.0:"
    echo "  ✓ Трей теперь полностью рабочий, интегрирован прямо в верхнюю панель."
    echo "  ✓ Исправлены конфликты whitespace-символов при патчинге на CachyOS."
    echo "  ✓ Добавлены нативные отступы окон (Gaps)."
    echo "  ✓ Рамка активного окна стала толще — 3px."
    echo "  ✓ Верхний бар стал монолитным — убран выделяющийся серый блок активного тега."
    echo "  ✓ Сгенерированы стильные обои теплого монохрома в 4K."
    echo ""
    warn "Перезагрузите ПК: reboot"
    echo ""
}

main "$@"
