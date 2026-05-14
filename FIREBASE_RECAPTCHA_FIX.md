# Firebase reCAPTCHA Still Showing - Complete Fix Guide

## ✅ You've Done:
- ✅ Added SHA-1 and SHA-256 to `com.matchvibe.app`
- ✅ Built APK locally after adding fingerprints
- ✅ Using release keystore

## 🔍 Why reCAPTCHA Still Shows

Even with SHA fingerprints added, Firebase **may still show reCAPTCHA** in these cases:

### 1. **Play Integrity API Behavior** (Most Common)
Firebase uses Play Integrity API which **sometimes shows reCAPTCHA** even with valid fingerprints:
- First-time verification on a device
- Device doesn't have Play Services properly configured
- Network issues preventing Play Integrity check
- **This is NORMAL behavior** - Firebase falls back to reCAPTCHA

### 2. **Fingerprint Mismatch**
The fingerprints in Firebase don't match the APK signature.

**Verify:**
```powershell
cd frontend
# Extract fingerprints from your keystore
keytool -list -v -keystore keystore/upload-keystore.jks -alias upload
```

Compare SHA-1 and SHA-256 with what's in Firebase Console.

### 3. **Propagation Delay**
Firebase changes can take **up to 24 hours** to fully propagate, especially for Play Integrity API.

### 4. **Device/Network Issues**
- Device doesn't have Google Play Services updated
- Network blocking Play Integrity API
- Device is rooted/unlocked (Play Integrity may fail)

## 🛠️ Solutions

### Solution 0: Play Store App Signing (REQUIRED for production)

Google Play re-signs release builds with the **App signing key**. Upload-key SHA alone is not enough.

1. Google Play Console → **App integrity** → **App signing key certificate**
2. Copy **SHA-1** and **SHA-256** from that section (not only the upload certificate)
3. Firebase Console → Project `matchvibe-d55f9` → Android app `com.matchvibe.app` → add both fingerprints
4. Download an updated `android/app/google-services.json` and rebuild the release bundle

Without Play signing fingerprints, phone OTP often fails on Play Store builds while Google Sign-In still works.

### Solution 1: Verify Fingerprints Match (CRITICAL)

**Step 1: Get fingerprints from your keystore:**
```powershell
cd frontend
keytool -list -v -keystore keystore/upload-keystore.jks -alias upload
# Enter password when prompted: Million$99
```

**Step 2: Compare with Firebase Console:**
1. Go to Firebase Console → Project Settings → `com.matchvibe.app`
2. Check SHA-1 and SHA-256 listed
3. **Do they EXACTLY match?** (including colons and case)

**If they DON'T match:**
- You added wrong fingerprints
- Wrong keystore was used
- Fix: Add the correct fingerprints

### Solution 2: Re-download google-services.json

After adding fingerprints, Firebase may update the config:

1. Firebase Console → Project Settings → `com.example.zztherapy`
2. Click **"Download google-services.json"**
3. Replace `frontend/android/app/google-services.json`
4. Rebuild APK:
   ```powershell
   cd frontend
   flutter clean
   flutter build apk --release
   ```

### Solution 3: Wait and Retry

Play Integrity API propagation can take **24 hours**:
- Wait 24 hours after adding fingerprints
- Clear app data
- Reinstall APK
- Test again

### Solution 4: Check Play Services

Ensure device has:
- Google Play Services installed and updated
- Google Play Store installed
- Device is not rooted/unlocked (may cause Play Integrity to fail)

### Solution 5: Temporary Testing Workaround

For **testing only**, you can disable app verification:

**File:** `frontend/lib/features/auth/providers/auth_provider.dart`

**Line 135, change:**
```dart
// FROM:
if (kDebugMode) {
  await _auth!.setSettings(appVerificationDisabledForTesting: true);
}

// TO (TEMPORARY - REMOVE FOR PRODUCTION):
if (kDebugMode || true) {  // ⚠️ TEMPORARY - Remove "|| true" before production!
  await _auth!.setSettings(appVerificationDisabledForTesting: true);
}
```

**⚠️ WARNING:** This disables security checks. **Remove `|| true` before production release!**

## 🔍 Diagnostic Steps

### Check 1: Verify APK Signature
```powershell
# Using keytool (if you have the APK)
cd frontend
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

Compare SHA-1/SHA-256 with Firebase Console.

### Check 2: Verify Build Used Release Keystore
Check build logs when building APK - should show:
```
> Task :app:packageRelease
Signing with release keystore
```

### Check 3: Check Firebase Console
1. Firebase Console → Project Settings
2. App: `com.matchvibe.app`
3. SHA certificate fingerprints section
4. Should show **both** SHA-1 and SHA-256

### Check 4: Check Logs
Look for these error codes in app logs:
- `captcha-check-failed` - Play Integrity failed
- `app-not-authorized` - Fingerprints don't match
- `invalid-app-credential` - Package name mismatch

## 📋 Most Likely Fix

**90% of cases:** Fingerprints don't match or need time to propagate.

**Action Plan:**
1. ✅ Verify fingerprints match exactly
2. ✅ Re-download `google-services.json`
3. ✅ Rebuild APK
4. ✅ Wait 24 hours
5. ✅ Test on different device/network

## 🎯 Expected Behavior

**With fingerprints added correctly:**
- **First time on device:** May show reCAPTCHA (normal)
- **Subsequent attempts:** Should skip reCAPTCHA
- **Different devices:** May show reCAPTCHA once, then skip

**If reCAPTCHA shows EVERY time:**
- Fingerprints don't match
- Play Integrity API failing
- Need to verify keystore matches Firebase

## ⚡ Quick Test

Try this to verify fingerprints are working:

1. **Uninstall app completely**
2. **Clear device cache** (if possible)
3. **Reinstall fresh APK**
4. **Try phone auth**

If reCAPTCHA shows on first attempt but NOT on second attempt → **Fingerprints are working!** (First-time verification is normal)

If reCAPTCHA shows EVERY time → **Fingerprints don't match** (Need to verify)
