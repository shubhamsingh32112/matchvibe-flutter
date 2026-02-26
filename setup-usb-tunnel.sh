#!/bin/bash
# USB Reverse Tunnel Setup Script
# This script sets up ADB reverse tunnel to bypass Wi-Fi routing issues
# Run this script BEFORE starting your Flutter app

echo "═══════════════════════════════════════════════════════"
echo "🔧 USB Reverse Tunnel Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check if ADB is available
echo "📱 Checking ADB availability..."
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found in PATH!"
    echo ""
    echo "Please install Android SDK Platform Tools:"
    echo "  1. Download from: https://developer.android.com/tools/releases/platform-tools"
    echo "  2. Add to PATH, or run this script from SDK platform-tools folder"
    echo ""
    exit 1
fi

echo "✅ ADB found: $(which adb)"
echo ""

# Check if device is connected
echo "📱 Checking for connected Android device..."
DEVICES=$(adb devices | grep -E "device$")

if [ -z "$DEVICES" ]; then
    echo "❌ No Android device found!"
    echo ""
    echo "Please:"
    echo "  1. Connect your Android device via USB"
    echo "  2. Enable USB Debugging on the device"
    echo "  3. Accept the USB debugging prompt on device"
    echo "  4. Run this script again"
    echo ""
    exit 1
fi

DEVICE_COUNT=$(echo "$DEVICES" | wc -l)
echo "✅ Found $DEVICE_COUNT connected device(s)"
echo ""

# Check if reverse tunnel already exists
echo "🔍 Checking existing reverse tunnels..."
EXISTING_TUNNELS=$(adb reverse --list)

if echo "$EXISTING_TUNNELS" | grep -q "tcp:3000"; then
    echo "⚠️  Reverse tunnel for port 3000 already exists"
    echo "   Removing existing tunnel..."
    adb reverse --remove tcp:3000 2>/dev/null
    sleep 0.5
fi

# Set up reverse tunnel
echo "🔧 Setting up reverse tunnel: tcp:3000 -> tcp:3000"
if ! adb reverse tcp:3000 tcp:3000; then
    echo "❌ Failed to set up reverse tunnel!"
    echo ""
    exit 1
fi

echo "✅ Reverse tunnel established successfully!"
echo ""

# Verify tunnel
echo "🧪 Verifying reverse tunnel..."
TUNNELS=$(adb reverse --list)
if echo "$TUNNELS" | grep -q "tcp:3000"; then
    echo "✅ Tunnel verified: $TUNNELS"
else
    echo "⚠️  Tunnel may not be active"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Update Flutter app configuration:"
echo "   Open: frontend/lib/core/constants/app_constants.dart"
echo "   Change: USE_USB_TUNNEL = true"
echo ""
echo "2. Hot restart your Flutter app (not just hot reload):"
echo "   Press 'R' in Flutter terminal, or:"
echo "   flutter run"
echo ""
echo "3. The app will now use: http://localhost:3000"
echo "   This bypasses Wi-Fi routing completely!"
echo ""
echo "💡 To remove tunnel later, run:"
echo "   adb reverse --remove tcp:3000"
echo ""
echo "═══════════════════════════════════════════════════════"
