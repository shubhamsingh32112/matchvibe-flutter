# ============================================================
# ADB Reverse Tunnel Setup Script (ZZTherapy / Eazy Talks)
# ============================================================
# Sets up reverse tunnels on ALL connected Android devices
# so they can reach your laptop services via localhost:
#   - Backend API: localhost:3000
#   - Wallet checkout website: localhost:8080
#
# Usage: .\setup-adb-tunnels.ps1
# Run this after plugging in phones or after USB reconnect/reboot
# ============================================================

$ports = @(3000, 8080)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADB Reverse Tunnel Setup (ports: $($ports -join ', '))" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get connected devices
$rawOutput = adb devices 2>&1
$devices = $rawOutput | Select-String "^\S+\s+device$" | ForEach-Object {
    ($_ -split "\s+")[0]
}

if (-not $devices -or $devices.Count -eq 0) {
    Write-Host "[X] No devices found. Make sure:" -ForegroundColor Red
    Write-Host "    - Phone is plugged in via USB" -ForegroundColor Yellow
    Write-Host "    - USB debugging is enabled" -ForegroundColor Yellow
    Write-Host "    - You authorized the computer on the phone" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Found $($devices.Count) device(s):" -ForegroundColor Green
Write-Host ""

$success = 0
$failed = 0

foreach ($serial in $devices) {
    Write-Host "  [$serial] " -NoNewline

    foreach ($port in $ports) {
        try {
            $result = adb -s $serial reverse tcp:$port tcp:$port 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "tcp:$port OK" -ForegroundColor Green
                $success++
            } else {
                Write-Host "tcp:$port FAILED - $result" -ForegroundColor Red
                $failed++
            }
        } catch {
            Write-Host "tcp:$port ERROR - $_" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Cyan

# Verify all tunnels
Write-Host ""
Write-Host "Verifying tunnels:" -ForegroundColor Cyan
Write-Host ""

foreach ($serial in $devices) {
    $list = adb -s $serial reverse --list 2>&1
    foreach ($port in $ports) {
        $hasTunnel = $list | Select-String "tcp:$port"
        if ($hasTunnel) {
            Write-Host "  [$serial] tcp:$port -> tcp:$port" -ForegroundColor Green
        } else {
            Write-Host "  [$serial] tcp:$port NOT ACTIVE" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Result: $success OK, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failed -eq 0) {
    Write-Host "All devices can reach backend at http://localhost:3000 and checkout at http://localhost:8080" -ForegroundColor Green
} else {
    Write-Host "Some devices failed. Check USB connections." -ForegroundColor Yellow
}

Write-Host ""
