# USB Reverse Tunnel Setup Script
# This script sets up ADB reverse tunnel to bypass Wi-Fi routing issues
# Run this script BEFORE starting your Flutter app

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔧 USB Reverse Tunnel Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if ADB is available
Write-Host "📱 Checking ADB availability..." -ForegroundColor Yellow
$adbPath = Get-Command adb -ErrorAction SilentlyContinue

if (-not $adbPath) {
    Write-Host "❌ ADB not found in PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Android SDK Platform Tools:" -ForegroundColor Yellow
    Write-Host "  1. Download from: https://developer.android.com/tools/releases/platform-tools" -ForegroundColor White
    Write-Host "  2. Add to PATH, or run this script from SDK platform-tools folder" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ ADB found: $($adbPath.Source)" -ForegroundColor Green
Write-Host ""

# Check if device is connected
Write-Host "Checking for connected Android device..." -ForegroundColor Yellow
$deviceList = adb devices
$devices = $deviceList | Select-String -Pattern "device$"

if (-not $devices) {
    Write-Host "ERROR: No Android device found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "  1. Connect your Android device via USB" -ForegroundColor White
    Write-Host "  2. Enable USB Debugging on the device" -ForegroundColor White
    Write-Host "  3. Accept the USB debugging prompt on device" -ForegroundColor White
    Write-Host "  4. Run this script again" -ForegroundColor White
    Write-Host ""
    exit 1
}

$deviceCount = ($devices | Measure-Object).Count
Write-Host "SUCCESS: Found $deviceCount connected device(s)" -ForegroundColor Green
Write-Host ""

# Set up reverse tunnel for ALL connected devices
$successCount = 0
$failCount = 0

foreach ($deviceLine in $devices) {
    $deviceId = ($deviceLine -split '\s+')[0]
    Write-Host "Processing device: $deviceId" -ForegroundColor Cyan
    
    # Check if reverse tunnel already exists
    $existingTunnels = adb -s $deviceId reverse --list 2>&1
    
    if ($existingTunnels -match "tcp:3000") {
        Write-Host "  WARNING: Reverse tunnel for port 3000 already exists" -ForegroundColor Yellow
        Write-Host "  Removing existing tunnel..." -ForegroundColor Yellow
        adb -s $deviceId reverse --remove tcp:3000 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
    }
    
    # Set up reverse tunnel
    Write-Host "  Setting up reverse tunnel: tcp:3000 -> tcp:3000" -ForegroundColor Yellow
    $result = adb -s $deviceId reverse tcp:3000 tcp:3000 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  SUCCESS: Reverse tunnel established for $deviceId" -ForegroundColor Green
        
        # Verify tunnel
        $tunnels = adb -s $deviceId reverse --list 2>&1
        if ($tunnels -match "tcp:3000") {
            Write-Host "  Verified: $tunnels" -ForegroundColor Gray
            $successCount++
        } else {
            Write-Host "  WARNING: Tunnel may not be active" -ForegroundColor Yellow
            $failCount++
        }
    } else {
        Write-Host "  ERROR: Failed to set up reverse tunnel for $deviceId" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        $failCount++
    }
    Write-Host ""
}

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Successful: $successCount device(s)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount device(s)" -ForegroundColor Red
}
Write-Host ""

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Update Flutter app configuration:" -ForegroundColor White
Write-Host "   Open: frontend/lib/core/constants/app_constants.dart" -ForegroundColor Gray
Write-Host "   Change: USE_USB_TUNNEL = true" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Hot restart your Flutter app (not just hot reload):" -ForegroundColor White
Write-Host "   Press 'R' in Flutter terminal, or:" -ForegroundColor Gray
Write-Host "   flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "3. The app will now use: http://localhost:3000" -ForegroundColor White
Write-Host "   This bypasses Wi-Fi routing completely!" -ForegroundColor Gray
Write-Host ""
Write-Host "💡 To remove tunnel later, run:" -ForegroundColor Yellow
Write-Host "   adb reverse --remove tcp:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
