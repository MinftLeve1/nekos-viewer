#!/bin/bash
# build-nekos-viewer.sh - Version 6 (PNG Icon + v1.0.3)
# Run this on your Debian 13 (arm64) system

set -e

WORK_DIR="$HOME/nekos-viewer-build"
DEB_DIR="$WORK_DIR/nekos-viewer-deb"

echo "🐱 Building Nekos Viewer .deb package (v1.0.3 with PNG icon)..."

# Clean up
rm -rf "$WORK_DIR"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/share/nekos-viewer"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/pixmaps"

# ============================================
# 1. Main Python application
# ============================================
cat > "$DEB_DIR/usr/share/nekos-viewer/nekos-viewer.py" << 'PYEOF'
#!/usr/bin/env python3
"""Nekos Viewer v1.0.3 - GTK4 app for Nekos.moe random images with Menu Bar"""

import sys
import json
import threading
import urllib.request
import urllib.error
import webbrowser
import subprocess
from pathlib import Path

try:
    import gi
    gi.require_version('Gtk', '4.0')
    gi.require_version('GdkPixbuf', '2.0')
    from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Gio
except ImportError:
    print("Error: Install GTK4 first: sudo apt install python3-gi gir1.2-gtk-4.0")
    sys.exit(1)

API_BASE = "https://nekos.moe/api/v1"
USER_AGENT = "NekosViewer (debian-package, v1.0.3)"
VERSION = "1.0.3"
BUILD = "26-07-13_04"


class NekosViewer(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Nekos Viewer")
        self.set_default_size(850, 750)

        self.current_image_data = None
        self.current_image_bytes = None

        # Main vertical box
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_child(main_box)

        # === MENU BAR ===
        self._create_menu_bar(main_box)

        # === CONTENT AREA ===
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        content_box.set_margin_top(15)
        content_box.set_margin_bottom(15)
        content_box.set_margin_start(15)
        content_box.set_margin_end(15)
        main_box.append(content_box)

        # 标题已删除 (v1.0.3)

        # 小字已删除 (v1.0.3)

        # Controls
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        controls.set_halign(Gtk.Align.CENTER)
        controls.set_margin_bottom(10)

        self.nsfw_switch = Gtk.Switch()
        self.nsfw_switch.set_active(False)
        nsfw_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        nsfw_box.append(Gtk.Label(label="NSFW:"))
        nsfw_box.append(self.nsfw_switch)
        controls.append(nsfw_box)

        self.refresh_btn = Gtk.Button(label="🔄 刷新图片")
        self.refresh_btn.add_css_class("suggested-action")
        self.refresh_btn.connect("clicked", self.on_refresh)
        controls.append(self.refresh_btn)

        self.save_btn = Gtk.Button(label="💾 保存图片")
        self.save_btn.set_sensitive(False)
        self.save_btn.connect("clicked", self.on_save)
        controls.append(self.save_btn)

        content_box.append(controls)

        # Status
        self.status_label = Gtk.Label(label="点击刷新获取图片 (或使用文件菜单)")
        self.status_label.set_margin_bottom(5)
        content_box.append(self.status_label)

        # Image display
        self.image_frame = Gtk.Frame()
        self.image_frame.set_vexpand(True)
        self.image_frame.set_hexpand(True)

        self.image_view = Gtk.Picture()
        self.image_view.set_can_shrink(True)
        self.image_view.set_content_fit(Gtk.ContentFit.CONTAIN)
        self.image_frame.set_child(self.image_view)
        content_box.append(self.image_frame)

        # Info (画师和 ID，标签已删除 v1.0.3)
        self.info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        self.info_box.set_margin_top(10)

        self.artist_label = Gtk.Label(label="画师: -")
        # 标签栏已删除 (v1.0.3)
        self.id_label = Gtk.Label(label="ID: -")

        self.info_box.append(self.artist_label)
        # 标签栏已删除 (v1.0.3)
        self.info_box.append(self.id_label)
        content_box.append(self.info_box)

        # Auto-load on start
        GLib.idle_add(self.on_refresh, None)

    def _create_menu_bar(self, parent_box):
        """Create the top menu bar using GMenuModel and Gtk.PopoverMenuBar"""

        # Create File menu model
        file_menu = Gio.Menu.new()
        file_menu.append("保存当前图片", "win.save-image")
        file_menu.append("退出程序", "win.quit")

        # Create About menu model
        about_menu = Gio.Menu.new()
        about_menu.append("前往 Nekos.moe", "win.open-website")
        about_menu.append("关于程序", "win.about")

        # Create main menu bar model
        menu_bar_model = Gio.Menu.new()
        menu_bar_model.append_submenu("文件", file_menu)
        menu_bar_model.append_submenu("关于", about_menu)

        # Create PopoverMenuBar from model
        menu_bar = Gtk.PopoverMenuBar.new_from_model(menu_bar_model)
        parent_box.append(menu_bar)

        # Setup window actions
        self._setup_actions()

    def _setup_actions(self):
        """Setup window actions for menu items"""

        # Save Image action (Ctrl+S)
        save_action = Gio.SimpleAction.new("save-image", None)
        save_action.connect("activate", self.on_menu_save)
        self.add_action(save_action)
        self.get_application().set_accels_for_action("win.save-image", ["<Ctrl>s"])

        # Quit action (Ctrl+Q)
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self.on_menu_quit)
        self.add_action(quit_action)
        self.get_application().set_accels_for_action("win.quit", ["<Ctrl>q"])

        # Open Website action
        website_action = Gio.SimpleAction.new("open-website", None)
        website_action.connect("activate", self.on_open_website)
        self.add_action(website_action)

        # About action
        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self.on_about)
        self.add_action(about_action)

    def on_menu_save(self, action, param):
        """Menu: File -> Save Current Image"""
        if self.current_image_data:
            self.on_save(None)
        else:
            self.status_label.set_text("❌ 没有可保存的图片，请先刷新")

    def on_menu_quit(self, action, param):
        """Menu: File -> Exit"""
        self.close()

    def on_open_website(self, action, param):
        """Menu: About -> Go to Nekos.moe"""
        try:
            subprocess.Popen(["xdg-open", "https://nekos.moe"], 
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.status_label.set_text("🌐 正在打开 nekos.moe...")
        except Exception:
            try:
                webbrowser.open("https://nekos.moe")
            except Exception as e:
                self.status_label.set_text(f"❌ 无法打开浏览器: {str(e)}")

    def on_about(self, action, param):
        """Menu: About -> About Program"""
        dialog = Gtk.AboutDialog(transient_for=self, modal=True)
        dialog.set_program_name("Nekos Viewer")
        dialog.set_version(f"{VERSION} (build {BUILD})")
        dialog.set_comments("A simple GTK4 application for fetching and displaying\nrandom images from the Nekos.moe API.")
        dialog.set_copyright(
            "Copyright © 2018 Brussell\n"
            "Copyright © 2018-2024 Nekos\n"
            "Copyright © 2024-2026 MKY-AN20's Home\n\n"
            "All rights reserved.\n\n"
            "Developed by: MKY-AN20 & Kimi AI"
        )
        dialog.set_website("https://nekos.moe")
        dialog.set_website_label("https://nekos.moe")
        dialog.set_license_type(Gtk.License.CUSTOM)
        dialog.set_license(
            "Nekos Viewer is built for the Nekos.moe community.\n\n"
            "All image content belongs to their respective artists and uploaders.\n"
            "This application is an unofficial third-party tool."
        )
        dialog.set_logo_icon_name("nekos-viewer")
        dialog.add_credit_section("Developers", ["MKY-AN20", "Kimi AI"])
        dialog.add_credit_section("API", ["Nekos.moe (Brussell)"])
        dialog.present()

    def on_refresh(self, button):
        """Fetch a new random image"""
        self.refresh_btn.set_sensitive(False)
        self.save_btn.set_sensitive(False)
        self.status_label.set_text("🔄 正在获取图片...")

        thread = threading.Thread(target=self._fetch_image)
        thread.daemon = True
        thread.start()
        return False

    def _fetch_image(self):
        """Background thread for API call"""
        try:
            nsfw = "true" if self.nsfw_switch.get_active() else "false"
            url = f"{API_BASE}/random/image?nsfw={nsfw}&count=1"

            req = urllib.request.Request(url, headers={
                "User-Agent": USER_AGENT,
                "Accept": "application/json"
            })

            with urllib.request.urlopen(req, timeout=15) as response:
                data = json.loads(response.read().decode())
                images = data.get("images", [])

                if not images:
                    GLib.idle_add(self._show_error, "未找到图片")
                    return

                img_data = images[0]
                img_id = img_data["id"]
                img_url = f"https://nekos.moe/image/{img_id}"

                img_req = urllib.request.Request(img_url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(img_req, timeout=30) as img_response:
                    img_bytes = img_response.read()

                GLib.idle_add(self._display_image, img_bytes, img_data)

        except urllib.error.HTTPError as e:
            GLib.idle_add(self._show_error, f"HTTP 错误: {e.code}")
        except Exception as e:
            GLib.idle_add(self._show_error, f"错误: {str(e)}")

    def _display_image(self, img_bytes, img_data):
        """Display the downloaded image in the main thread"""
        try:
            loader = GdkPixbuf.PixbufLoader()
            loader.write(img_bytes)
            loader.close()
            pixbuf = loader.get_pixbuf()

            if pixbuf:
                texture = Gdk.Texture.new_for_pixbuf(pixbuf)
                self.image_view.set_paintable(texture)
                self.current_image_data = img_data
                self.current_image_bytes = img_bytes

                artist = img_data.get("artist", "Unknown")
                # 标签已删除 (v1.0.3)
                img_id = img_data.get("id", "Unknown")
                nsfw = img_data.get("nsfw", False)
                likes = img_data.get("likes", 0)

                self.artist_label.set_text(f"🎨 画师: {artist}")
                # 标签已删除 (v1.0.3)
                self.id_label.set_text(f"🆔 ID: {img_id} | ❤️ {likes} | 🔞 {nsfw}")

                self.status_label.set_text(f"✅ 已加载图片 ({len(img_bytes)//1024} KB)")
                self.save_btn.set_sensitive(True)
            else:
                self._show_error("无法加载图片")

        except Exception as e:
            self._show_error(f"显示错误: {str(e)}")
        finally:
            self.refresh_btn.set_sensitive(True)
        return False

    def _show_error(self, message):
        """Show error message"""
        self.status_label.set_text(f"❌ {message}")
        self.refresh_btn.set_sensitive(True)
        return False

    def on_save(self, button):
        """Save current image to Downloads"""
        if not self.current_image_data:
            return

        img_id = self.current_image_data["id"]
        downloads = Path.home() / "Downloads"
        downloads.mkdir(exist_ok=True)
        filepath = downloads / f"nekos_{img_id}.jpg"

        try:
            if self.current_image_bytes:
                with open(filepath, 'wb') as f:
                    f.write(self.current_image_bytes)
            else:
                img_url = f"https://nekos.moe/image/{img_id}"
                req = urllib.request.Request(img_url, headers={"User-Agent": USER_AGENT})

                with urllib.request.urlopen(req, timeout=30) as response:
                    with open(filepath, 'wb') as f:
                        f.write(response.read())

            self.status_label.set_text(f"💾 已保存到: {filepath}")
        except Exception as e:
            self.status_label.set_text(f"❌ 保存失败: {str(e)}")


class NekosApp(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id="com.example.nekos-viewer",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )

    def do_activate(self):
        window = NekosViewer(self)
        window.present()


def main():
    app = NekosApp()
    app.run(sys.argv)


if __name__ == "__main__":
    main()
PYEOF

chmod 755 "$DEB_DIR/usr/share/nekos-viewer/nekos-viewer.py"

# ============================================
# 2. Launcher script
# ============================================
cat > "$DEB_DIR/usr/bin/nekos-viewer" << 'BINEOF'
#!/bin/bash
exec python3 /usr/share/nekos-viewer/nekos-viewer.py "$@"
BINEOF

chmod 755 "$DEB_DIR/usr/bin/nekos-viewer"

# ============================================
# 3. Desktop file (updated for PNG icon)
# ============================================
cat > "$DEB_DIR/usr/share/applications/nekos-viewer.desktop" << 'DESKEOF'
[Desktop Entry]
Name=Nekos Viewer
Name[zh_CN]=Nekos 图片查看器
Comment=Fetch random images from Nekos.moe
Comment[zh_CN]=从 Nekos.moe 获取随机图片
Exec=nekos-viewer
Icon=nekos-viewer
Type=Application
Categories=Network;Graphics;Viewer;
Terminal=false
StartupNotify=true
DESKEOF

# ============================================
# 4. Copy PNG icon from build folder
# ============================================
if [ -f "$DEB_DIR/../../nekos-viewer.png" ]; then
    echo "📷 Found nekos-viewer.png in build folder, copying..."
    cp "$DEB_DIR/../../nekos-viewer.png" "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
elif [ -f "$HOME/nekos-viewer.png" ]; then
    echo "📷 Found nekos-viewer.png in home, copying..."
    cp "$HOME/nekos-viewer.png" "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
else
    echo "⚠️  Warning: nekos-viewer.png not found!"
    echo "   Please place nekos-viewer.png in the same folder as this script"
    echo "   or in your home directory before running."
    echo "   Creating placeholder SVG as fallback..."

    cat > "$DEB_DIR/usr/share/pixmaps/nekos-viewer.svg" << 'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e"/>
      <stop offset="100%" style="stop-color:#16213e"/>
    </linearGradient>
    <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ff6b6b"/>
      <stop offset="100%" style="stop-color:#feca57"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="24" fill="url(#bg)"/>
  <polygon points="28,45 45,20 55,50" fill="url(#accent)"/>
  <polygon points="100,45 83,20 73,50" fill="url(#accent)"/>
  <circle cx="64" cy="70" r="32" fill="#2d2d44"/>
  <ellipse cx="52" cy="65" rx="6" ry="8" fill="#feca57"/>
  <ellipse cx="76" cy="65" rx="6" ry="8" fill="#feca57"/>
  <circle cx="53" cy="64" r="3" fill="#1a1a2e"/>
  <circle cx="77" cy="64" r="3" fill="#1a1a2e"/>
  <polygon points="64,72 60,78 68,78" fill="#ff6b6b"/>
  <path d="M 56 82 Q 64 90 72 82" stroke="#ff6b6b" stroke-width="2" fill="none"/>
  <line x1="35" y1="70" x2="20" y2="68" stroke="#888" stroke-width="1.5"/>
  <line x1="35" y1="75" x2="18" y2="76" stroke="#888" stroke-width="1.5"/>
  <line x1="93" y1="70" x2="108" y2="68" stroke="#888" stroke-width="1.5"/>
  <line x1="93" y1="75" x2="110" y2="76" stroke="#888" stroke-width="1.5"/>
</svg>
SVGEOF
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.svg"
fi

# ============================================
# 5. DEBIAN/control (v1.0.3)
# ============================================
cat > "$DEB_DIR/DEBIAN/control" << 'CTRLEOF'
Package: nekos-viewer
Version: 1.0.3
Section: web
Priority: optional
Architecture: all
Depends: python3, python3-gi, gir1.2-gtk-4.0, gir1.2-gdkpixbuf-2.0
Maintainer: Nekos Viewer Team <nekos@example.com>
Description: Random image viewer for Nekos.moe
 A simple GTK4 application that fetches and displays random
 images from the Nekos.moe API. Features menu bar, NSFW toggle,
 image save, and about dialog. Build 26-07-13_04.
CTRLEOF

# ============================================
# 6. Set ALL permissions correctly
# ============================================
echo "🔧 Setting permissions..."

chmod 755 "$DEB_DIR/DEBIAN"
chmod 644 "$DEB_DIR/DEBIAN/control"
chmod 755 "$DEB_DIR/usr/bin/nekos-viewer"
chmod 755 "$DEB_DIR/usr/share/nekos-viewer/nekos-viewer.py"
chmod 644 "$DEB_DIR/usr/share/applications/nekos-viewer.desktop"

# Set icon permissions
if [ -f "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png" ]; then
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
fi
if [ -f "$DEB_DIR/usr/share/pixmaps/nekos-viewer.svg" ]; then
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.svg"
fi

# Verify
echo "📋 Verifying permissions:"
find "$DEB_DIR" -type d -exec stat -c "%a %n" {} \;
find "$DEB_DIR" -type f -exec stat -c "%a %n" {} \;

# ============================================
# 7. Build the .deb package
# ============================================
echo "📦 Building .deb package..."
dpkg-deb --build "$DEB_DIR" "$HOME/nekos-viewer_1.0.3_all-fix.deb"

# Verify
if [ -f "$HOME/nekos-viewer_1.0.3_all.deb" ]; then
    echo ""
    echo "✅ Build successful!"
    echo "   Package: $HOME/nekos-viewer_1.0.3_all.deb"
    ls -lh "$HOME/nekos-viewer_1.0.3_all.deb"
    echo ""
    echo "📋 To install:"
    echo "   sudo dpkg -i ~/nekos-viewer_1.0.3_all.deb"
    echo "   sudo apt --fix-broken install"
    echo ""
    echo "🚀 To run:"
    echo "   nekos-viewer"
else
    echo "❌ Build failed!"
    exit 1
fi