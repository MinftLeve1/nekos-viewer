<p align="center">
  <img src="https://3w.mky-an20.os.kg/nekos-viewer/nekos.png" alt="图标"/>
</p>
<div align="center">
 Nekos Viewer
</div>

[![Version](https://img.shields.io/badge/version-1.0.3-blue)](https://github.com/MinftLeve1/nekos-viewer/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)](https://github.com/MinftLeve1/nekos-viewer)
[![CI](https://github.com/MinftLeve1/nekos-viewer/actions/workflows/build.yml/badge.svg)](https://github.com/MinftLeve1/nekos-viewer/actions)

> A simple GTK4 application for fetching and displaying random images from [Nekos.moe](https://nekos.moe)
# <p>Warning, the screenshot is outdated! 
<br>
Version 1.0.3 has changes that don't match the screenshot.</p>
## Screenshot
![Screenshot](https://3w.mky-an20.os.kg/nekos-viewer/screenshot.png)
![Screenshot](https://3w.mky-an20.os.kg/nekos-viewer/screenshot2.png)

## ✨ Features

- 🎲 **One-click refresh** - Get a new random image instantly
- 🖼️ **Image display** - GTK4 hardware-accelerated rendering
- 🏷️ **Tag & artist info** - See who drew it and what tags it has
- 🔞 **NSFW toggle** - Switch between SFW and NSFW content
- 💾 **Save images** - Save to your Downloads folder
- 📋 **Menu bar** - File (Save, Exit) and About (Website, About dialog)
- ⌨️ **Keyboard shortcuts** - `Ctrl+S` to save, `Ctrl+Q` to quit

## 📦 Installation

### Debian / Ubuntu

```bash
wget https://github.com/MinftLeve1/nekos-viewer/releases/download/v1.0.3/nekos-viewer_1.0.3_all.deb
sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-gdkpixbuf-2.0
sudo dpkg -i nekos-viewer_1.0.3_all.deb
sudo apt --fix-broken install
```

### From Source

```bash
git clone https://github.com/MinftLeve1/nekos-viewer.git
cd nekos-viewer
sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-gdkpixbuf-2.0
python3 nekos-viewer.py
```

## 🚀 Usage

```bash
nekos-viewer
```

## 🏗️ Building

```bash
chmod +x build-nekos-viewer.sh
./build-nekos-viewer.sh
```

## 🤖 CI/CD

Automatic builds and releases via GitHub Actions.

## 📜 License

MIT License - See [LICENSE](LICENSE)

## 🙏 Credits

- [Nekos.moe](https://nekos.moe) - API by Brussell
- MKY-AN20 & Kimi AI - Developers
'''
