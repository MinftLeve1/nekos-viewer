#!/bin/bash
# build-nekos-viewer.sh - Build .deb package for Nekos Viewer

set -e

WORK_DIR="$HOME/nekos-viewer-build"
DEB_DIR="$WORK_DIR/nekos-viewer-deb"

echo "🐱 Building Nekos Viewer .deb package (v1.0.2)..."

rm -rf "$WORK_DIR"
mkdir -p "$DEB_DIR"

# Copy source files
cp -r usr "$DEB_DIR/"
cp -r DEBIAN "$DEB_DIR/"

# Copy icon if exists
if [ -f "nekos-viewer.png" ]; then
    cp nekos-viewer.png "$DEB_DIR/usr/share/pixmaps/"
    chmod 644 "$DEB_DIR/usr/share/pixmaps/nekos-viewer.png"
else
    echo "⚠️  Warning: nekos-viewer.png not found, using placeholder"
fi

# Set permissions
chmod 755 "$DEB_DIR/DEBIAN"
chmod 644 "$DEB_DIR/DEBIAN/control"
chmod 755 "$DEB_DIR/usr/bin/nekos-viewer"
chmod 755 "$DEB_DIR/usr/share/nekos-viewer/nekos-viewer.py"
chmod 644 "$DEB_DIR/usr/share/applications/nekos-viewer.desktop"

# Build
dpkg-deb --build "$DEB_DIR" "$HOME/nekos-viewer_1.0.2_all.deb"

if [ -f "$HOME/nekos-viewer_1.0.2_all.deb" ]; then
    echo "✅ Build successful!"
    ls -lh "$HOME/nekos-viewer_1.0.2_all.deb"
else
    echo "❌ Build failed!"
    exit 1
fi
