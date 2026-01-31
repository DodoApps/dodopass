#!/bin/bash

# DodoPass Browser Extension Installer
# This script sets up native messaging for Chrome and Firefox

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "  DodoPass Browser Extension Installer"
echo "============================================"
echo ""

# Build the native messaging host
echo -e "${YELLOW}Building DodoPassHost...${NC}"
cd "$PROJECT_DIR/DodoPassHost"

if ! swift build -c release; then
    echo -e "${RED}Failed to build DodoPassHost${NC}"
    exit 1
fi

HOST_PATH="$PROJECT_DIR/DodoPassHost/.build/release/DodoPassHost"

if [ ! -f "$HOST_PATH" ]; then
    echo -e "${RED}DodoPassHost binary not found at $HOST_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}DodoPassHost built successfully${NC}"
echo ""

# Install native messaging manifests
NATIVE_HOST_NAME="com.dodopass.host"

# Chrome manifest locations
CHROME_MANIFEST_DIRS=(
    "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
    "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
)

# Firefox manifest location
FIREFOX_MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"

# Create Chrome/Chromium manifest
create_chrome_manifest() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/$NATIVE_HOST_NAME.json" << EOF
{
  "name": "$NATIVE_HOST_NAME",
  "description": "DodoPass Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://*/",
    "chromium-extension://*/"
  ]
}
EOF
    echo -e "  ${GREEN}✓${NC} Installed manifest to $dir"
}

# Create Firefox manifest
create_firefox_manifest() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/$NATIVE_HOST_NAME.json" << EOF
{
  "name": "$NATIVE_HOST_NAME",
  "description": "DodoPass Native Messaging Host",
  "path": "$HOST_PATH",
  "type": "stdio",
  "allowed_extensions": [
    "dodopass@dodopass.com"
  ]
}
EOF
    echo -e "  ${GREEN}✓${NC} Installed manifest to $dir"
}

echo -e "${YELLOW}Installing native messaging manifests...${NC}"

# Install for Chrome-based browsers
for dir in "${CHROME_MANIFEST_DIRS[@]}"; do
    browser_name=$(basename "$(dirname "$dir")")
    if [ -d "$(dirname "$dir")" ]; then
        create_chrome_manifest "$dir"
    fi
done

# Install for Firefox
create_firefox_manifest "$FIREFOX_MANIFEST_DIR"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Load the browser extension:"
echo "   - Open Chrome/Edge/Brave and go to: chrome://extensions"
echo "   - Enable 'Developer mode'"
echo "   - Click 'Load unpacked'"
echo "   - Select: $PROJECT_DIR/BrowserExtension"
echo ""
echo "2. Make sure DodoPass app is running and unlocked"
echo ""
echo "3. Click the DodoPass extension icon in your browser!"
echo ""

# Get extension ID instructions
echo -e "${YELLOW}Important:${NC} After loading the extension, you'll need to"
echo "update the manifest with your extension ID for production use."
echo ""
