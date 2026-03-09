# Verify APK Signature - Troubleshooting reCAPTCHA

## Step 1: Extract SHA from Installed APK

### Option A: Using apksigner (Recommended)
```powershell
# Install APK on device first, then:
adb shell pm path com.example.zztherapy
# Copy the path, then:
adb pull /data/app/com.example.zztherapy-*/base.apk temp.apk

# Extract certificate info:
apksigner verify --print-certs temp.apk
```

### Option B: Using keytool (if you have the APK file)
```powershell
# Extract certificate from APK
keytool -printcert -jarfile path/to/your/app-release.apk
```

Look for SHA-1 and SHA-256 in the output.

## Step 2: Compare with Firebase Console

1. Go to Firebase Console → Project Settings → Your Android app
2. Check the SHA fingerprints listed
3. **Do they match** the ones from your installed APK?

If they DON'T match:
- You added the wrong fingerprints (debug vs release)
- Your APK is signed with a different keystore
- You need to add the correct fingerprints
