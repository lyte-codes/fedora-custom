#!/usr/bin/env bash
#
# 50-theme -- one look, applied as widely as it actually can be.
#
# "Set a GTK theme and every app follows" is true of about two thirds of a
# real desktop. Three things break it, and this module handles each:
#
#   1. FLATPAK APPS ARE SANDBOXED and cannot see host themes at all. A theme
#      installed to /usr/share/themes is invisible to Firefox and Kdenlive.
#      They need the theme as a Flatpak *extension* -- see the note at the
#      bottom, and the matching entry added to 40-flatpak.sh's list.
#
#   2. QT APPS DO NOT READ GTK THEMES. Kdenlive is Qt. Pointing Qt at the GTK
#      theme via QT_QPA_PLATFORMTHEME is the closest thing to a fix.
#
#   3. GTK4 / LIBADWAITA APPS largely ignore custom themes by design. Rather
#      than fight that -- which produces broken-looking apps, not themed ones
#      -- the theme chosen here sidesteps it: adw-gtk3 IS the libadwaita look
#      ported back to GTK3. So GTK3 apps match GTK4 apps because both end up
#      looking like Adwaita, instead of the usual mismatch.
#
set -euxo pipefail

# --- The look ----------------------------------------------------------------
#
# Black and purple. The base theme stays adw-gtk3-dark because it is the only
# dark theme that exists BOTH in Fedora (for host apps) and on Flathub as a
# Gtk3theme extension (for sandboxed Flatpaks). Nothing purple exists on both
# sides -- checked Dracula, Catppuccin, Orchis, Nordic: all missing from one or
# the other. So purple is layered on top as CSS rather than picked as a theme.
GTK_THEME="adw-gtk3-dark"
ICON_THEME="Papirus-Dark"

# Change these four and everything below follows.
ACCENT="#a855f7"          # purple: selections, focus rings, active controls
ACCENT_HOVER="#c084fc"    # lighter, for hover
BG_BLACK="#0b0b0d"        # window/view background -- near-black, not #000
BG_RAISED="#151519"       # headerbars, sidebars, cards

# adw-gtk3-theme, not gnome-themes-extra: the latter is retired upstream and
# has no f44 branch at all. It is what used to ship /usr/share/themes/Adwaita-dark,
# which is why that theme name no longer resolves either.
#
# papirus-icon-theme-dark is named explicitly because the base package only
# *Recommends* it -- and overlay/etc/dnf/dnf.conf sets install_weak_deps=False,
# so recommendations are dropped. That setting is the whole no-bloat strategy;
# the cost is that subpackages must be asked for by name.
#
# adwaita-cursor-theme is already in the bootc base -- not repeated here.
dnf -y install \
    adw-gtk3-theme \
    papirus-icon-theme \
    papirus-icon-theme-dark

# --- 1. System-wide GTK3 default ---------------------------------------------
# /etc is writable and preserved on a bootc system, so this is a real default
# rather than something a rebuild would stamp over. A user's own
# ~/.config/gtk-3.0/settings.ini still wins, which is correct.
install -d /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
gtk-font-name=Cantarell 11
EOF

# The purple. adw-gtk3 follows libadwaita's colour names, so redefining these
# recolours the theme without forking it -- a theme update does not undo this.
#
# LIMITATION, because it will look like a bug otherwise: this file is on the
# host, and Flatpak apps cannot read it. Firefox and Kdenlive get the dark
# adw-gtk3 base from the Flathub extension, but NOT these purple accents.
# Style Firefox with a Firefox theme; Kdenlive picks colours up through
# QT_QPA_PLATFORMTHEME below.
cat > /etc/gtk-3.0/gtk.css <<EOF
@define-color accent_color ${ACCENT};
@define-color accent_bg_color ${ACCENT};
@define-color accent_fg_color #ffffff;
@define-color theme_selected_bg_color ${ACCENT};
@define-color theme_selected_fg_color #ffffff;

@define-color window_bg_color ${BG_BLACK};
@define-color view_bg_color ${BG_BLACK};
@define-color headerbar_bg_color ${BG_RAISED};
@define-color sidebar_bg_color ${BG_RAISED};
@define-color card_bg_color ${BG_RAISED};
@define-color popover_bg_color ${BG_RAISED};
@define-color theme_bg_color ${BG_BLACK};
@define-color theme_base_color ${BG_BLACK};

/* Selection and hover, which the colour definitions above do not always
   reach on their own depending on the widget. */
*:selected, *:checked { background-color: ${ACCENT}; }
button:hover { border-color: ${ACCENT_HOVER}; }
EOF

# GTK4 reads a different file and ignores the one above. libadwaita apps will
# not take a custom theme name, but they do honour the dark preference -- and
# since adw-gtk3 is Adwaita's look anyway, they already match.
install -d /etc/gtk-4.0
cat > /etc/gtk-4.0/settings.ini <<EOF
[Settings]
gtk-icon-theme-name=${ICON_THEME}
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF

# libadwaita ignores theme NAMES but does honour these colour definitions,
# so GTK4 apps get the same purple as GTK3 ones.
cat > /etc/gtk-4.0/gtk.css <<EOF
@define-color accent_color ${ACCENT};
@define-color accent_bg_color ${ACCENT};
@define-color accent_fg_color #ffffff;
@define-color window_bg_color ${BG_BLACK};
@define-color view_bg_color ${BG_BLACK};
@define-color headerbar_bg_color ${BG_RAISED};
@define-color sidebar_bg_color ${BG_RAISED};
@define-color card_bg_color ${BG_RAISED};
EOF

# --- 2. Xfce's own settings daemon -------------------------------------------
# Xfce does not read /etc/gtk-3.0/settings.ini for its own chrome -- xfsettingsd
# owns that, and reads xfconf. This is the system default channel; a user
# changing it in Appearance writes to their own profile and takes precedence.
install -d /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="${GTK_THEME}"/>
    <property name="IconThemeName" type="string" value="${ICON_THEME}"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="FontName" type="string" value="Cantarell 11"/>
  </property>
</channel>
EOF

# Window decorations are xfwm4's, not GTK's, and are themed separately.
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default-hdpi"/>
    <property name="title_font" type="string" value="Cantarell Bold 10"/>
  </property>
</channel>
EOF

# Xfce panel: black, no gradient, so it reads as one surface with the windows.
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="background-style" type="uint" value="1"/>
      <property name="background-rgba" type="array">
        <value type="double" value="0.043"/>
        <value type="double" value="0.043"/>
        <value type="double" value="0.051"/>
        <value type="double" value="1.0"/>
      </property>
    </property>
  </property>
</channel>
EOF

# Desktop background: flat black rather than the Fedora wallpaper. Solid
# colour also means no wallpaper file to ship in the image.
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="0"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.043"/>
            <value type="double" value="0.043"/>
            <value type="double" value="0.051"/>
            <value type="double" value="1.0"/>
          </property>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# --- 3. Qt apps (Kdenlive) ---------------------------------------------------
# Qt reads none of the above. QT_QPA_PLATFORMTHEME=gtk3 makes Qt apps pick up
# GTK colours and the GTK file dialog, which is the difference between
# Kdenlive looking like it belongs and looking like it was airlifted in.
#
# /etc/environment is read by PAM at login, so this reaches graphical sessions
# rather than only shells.
if ! grep -q '^QT_QPA_PLATFORMTHEME=' /etc/environment 2>/dev/null; then
    echo 'QT_QPA_PLATFORMTHEME=gtk3' >> /etc/environment
fi

# --- Note on Flatpak ---------------------------------------------------------
# Nothing above reaches a Flatpak app. Flatpaks read themes from their own
# runtime, so the theme has to exist there too -- installed as
# org.gtk.Gtk3theme.<Name> from Flathub. 40-flatpak.sh's list carries the
# matching entry; if you change GTK_THEME above, change that entry to match or
# your host and your apps will disagree.
