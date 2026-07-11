#!/usr/bin/env python3
"""Nekos Viewer v1.0.2 - GTK4 app for Nekos.moe random images"""

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
USER_AGENT = "NekosViewer (debian-package, v1.0.2)"
VERSION = "1.0.2"
BUILD = "26-07-11_03"


class NekosViewer(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Nekos Viewer")
        self.set_default_size(850, 750)

        self.current_image_data = None
        self.current_image_bytes = None

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_child(main_box)

        self._create_menu_bar(main_box)

        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        content_box.set_margin_top(15)
        content_box.set_margin_bottom(15)
        content_box.set_margin_start(15)
        content_box.set_margin_end(15)
        main_box.append(content_box)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header.set_halign(Gtk.Align.CENTER)
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">🐱 Nekos Viewer</span>')
        header.append(title)
        content_box.append(header)

        subtitle = Gtk.Label(label="随机获取 Nekos.moe 图片")
        subtitle.set_margin_bottom(10)
        content_box.append(subtitle)

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

        self.status_label = Gtk.Label(label="点击刷新获取图片 (或使用文件菜单)")
        self.status_label.set_margin_bottom(5)
        content_box.append(self.status_label)

        self.image_frame = Gtk.Frame()
        self.image_frame.set_vexpand(True)
        self.image_frame.set_hexpand(True)

        self.image_view = Gtk.Picture()
        self.image_view.set_can_shrink(True)
        self.image_view.set_content_fit(Gtk.ContentFit.CONTAIN)
        self.image_frame.set_child(self.image_view)
        content_box.append(self.image_frame)

        self.info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        self.info_box.set_margin_top(10)

        self.artist_label = Gtk.Label(label="画师: -")
        self.tags_label = Gtk.Label(label="标签: -")
        self.tags_label.set_wrap(True)
        self.tags_label.set_max_width_chars(60)
        self.id_label = Gtk.Label(label="ID: -")

        self.info_box.append(self.artist_label)
        self.info_box.append(self.tags_label)
        self.info_box.append(self.id_label)
        content_box.append(self.info_box)

        GLib.idle_add(self.on_refresh, None)

    def _create_menu_bar(self, parent_box):
        file_menu = Gio.Menu.new()
        file_menu.append("保存当前图片", "win.save-image")
        file_menu.append("退出程序", "win.quit")

        about_menu = Gio.Menu.new()
        about_menu.append("前往 Nekos.moe", "win.open-website")
        about_menu.append("关于程序", "win.about")

        menu_bar_model = Gio.Menu.new()
        menu_bar_model.append_submenu("文件(F)", file_menu)
        menu_bar_model.append_submenu("关于(A)", about_menu)

        menu_bar = Gtk.PopoverMenuBar.new_from_model(menu_bar_model)
        parent_box.append(menu_bar)

        self._setup_actions()

    def _setup_actions(self):
        save_action = Gio.SimpleAction.new("save-image", None)
        save_action.connect("activate", self.on_menu_save)
        self.add_action(save_action)
        self.get_application().set_accels_for_action("win.save-image", ["<Ctrl>s"])

        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", self.on_menu_quit)
        self.add_action(quit_action)
        self.get_application().set_accels_for_action("win.quit", ["<Ctrl>q"])

        website_action = Gio.SimpleAction.new("open-website", None)
        website_action.connect("activate", self.on_open_website)
        self.add_action(website_action)

        about_action = Gio.SimpleAction.new("about", None)
        about_action.connect("activate", self.on_about)
        self.add_action(about_action)

    def on_menu_save(self, action, param):
        if self.current_image_data:
            self.on_save(None)
        else:
            self.status_label.set_text("❌ 没有可保存的图片，请先刷新")

    def on_menu_quit(self, action, param):
        self.close()

    def on_open_website(self, action, param):
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
        self.refresh_btn.set_sensitive(False)
        self.save_btn.set_sensitive(False)
        self.status_label.set_text("🔄 正在获取图片...")

        thread = threading.Thread(target=self._fetch_image)
        thread.daemon = True
        thread.start()
        return False

    def _fetch_image(self):
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
                tags = img_data.get("tags", [])
                img_id = img_data.get("id", "Unknown")
                nsfw = img_data.get("nsfw", False)
                likes = img_data.get("likes", 0)

                self.artist_label.set_text(f"🎨 画师: {artist}")
                self.tags_label.set_text(f"🏷️ 标签: {', '.join(tags[:15])}")
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
        self.status_label.set_text(f"❌ {message}")
        self.refresh_btn.set_sensitive(True)
        return False

    def on_save(self, button):
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
