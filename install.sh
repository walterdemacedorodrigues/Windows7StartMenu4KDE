#!/bin/bash
# Installation script for Windows7StartMenu4KDE plasmoid

set -e

PLASMOID_NAME="Windows7StartMenu4KDE"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_NAME"

echo "========================================="
echo "Installing $PLASMOID_NAME plasmoid"
echo "========================================="

# Remove old installation if exists
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing old installation..."
    rm -rf "$INSTALL_DIR"
fi

# Create install directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"

# Copy files
echo "Copying files..."
cp -r contents "$INSTALL_DIR/"
cp metadata.json "$INSTALL_DIR/"
cp metadata.desktop "$INSTALL_DIR/"

echo ""
echo "========================================="
echo "Installation complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Right-click on the panel"
echo "2. Select 'Add Widgets...'"
echo "3. Search for 'Windows 7 Start Menu'"
echo "4. Add it to your panel"
echo ""
echo "OR restart plasmashell to reload:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
echo ""
