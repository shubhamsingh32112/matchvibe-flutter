# Firebase SHA Fingerprints Setup for Phone Auth (Android Release)

Even though you **don't use Google Sign-In**, Firebase Phone Authentication on Android release builds requires **SHA-1 and SHA-256 certificate fingerprints** to be registered in Firebase Console. This is because Firebase uses **Play Integrity API** (formerly SafetyNet) to verify your app's authenticity.

Without these fingerprints, users may encounter errors like:
- `app-not-authorized`
- `invalid-app-credential`
- `missing-client-identifier`
- `captcha-check-failed`

---

## Step 1: Generate Your Release Keystore (If Not Done Yet)

If you haven't created a release keystore yet, do this first:

### From `frontend/` directory:

```powershell
# Create keystore directory
mkdir keystore -Force

# Generate the keystore (you'll be prompted for passwords and certificate info)
keytool -genkeypair -v `
  -keystore .\keystore\upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

**Important prompts:**
- **Keystore password**: Choose a strong password (save it securely!)
- **Key password**: Usually same as keystore password (or different, your choice)
- **Name/Organization**: Enter your app details (e.g., "Match Vibe", "Your Company")

**Note**: If `keytool` is not found, install a JDK (or use Android Studio's embedded JDK) and ensure `keytool` is on your PATH.

---

## Step 2: Extract SHA-1 and SHA-256 from Your Keystore

### From `frontend/` directory:

```powershell
keytool -list -v -keystore .\keystore\upload-keystore.jks -alias upload
```

**You'll be prompted for the keystore password** (the one you set in Step 1).

### Example Output:

```
Alias name: upload
Creation date: Jan 15, 2024
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=Match Vibe, OU=Development, O=Your Company, L=City, ST=State, C=US
Issuer: CN=Match Vibe, OU=Development, O=Your Company, L=City, ST=State, C=US
Serial number: 1234567890abcdef
Valid from: Mon Jan 15 10:00:00 UTC 2024 until: Thu Jan 15 10:00:00 UTC 2034
Certificate fingerprints:
         SHA1: A1:B2:C3:D4:E5:F6:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
         SHA256: 12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF
Signature algorithm name: SHA256withRSA
Subject Public Key Algorithm: 2048-bit RSA key
Version: 3
```

**Copy both SHA-1 and SHA-256** values (the long hex strings).

---

## Step 3: Add SHA Fingerprints to Firebase Console

### 3.1 Open Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **matchvibe-d55f9**
3. Click the **⚙️ gear icon** (Project Settings) in the left sidebar

### 3.2 Navigate to Your Android App

1. Scroll down to **"Your apps"** section
2. Find your **production Android app**:
   - **App nickname**: `zztherapy (android)`
   - **Package name**: `com.example.zztherapy`
   - **App ID**: `1:911372372113:android:65d2a2d572d7cc564d1730`

3. Click on this app (or click the **"Add fingerprint"** button if it's visible)

### 3.3 Add SHA Fingerprints

1. Scroll to **"SHA certificate fingerprints"** section
2. Click **"Add fingerprint"** button
3. Paste your **SHA-1** fingerprint (from Step 2)
   - Format: `A1:B2:C3:D4:E5:F6:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12`
   - Click **"Save"**
4. Click **"Add fingerprint"** again
5. Paste your **SHA-256** fingerprint (from Step 2)
   - Format: `12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF`
   - Click **"Save"**

### 3.4 Verify

You should now see **both SHA-1 and SHA-256** listed under "SHA certificate fingerprints" for your `com.example.zztherapy` app.

---

## Step 4: Download Updated `google-services.json` (Optional)

After adding fingerprints, Firebase may update the `google-services.json` file. However, since you already have the file locally, you typically **don't need to re-download** it unless Firebase explicitly prompts you.

If you want to be safe, you can:
1. In Firebase Console → Your Android app → **"Download google-services.json"**
2. Replace `frontend/android/app/google-services.json` with the new file

**Note**: The fingerprints are stored server-side, so the JSON file itself doesn't change, but downloading ensures you have the latest config.

---

## Step 5: Test Phone Auth in Release Build

### 5.1 Build a Release APK/Bundle

```powershell
cd frontend

# For testing (APK is easier to install):
flutter build apk --release

# Or for Play Store (App Bundle):
flutter build appbundle --release
```

### 5.2 Install and Test

1. Install the release APK on a real device (not emulator)
2. Try phone number login (OTP flow)
3. If you see errors like `app-not-authorized` or `invalid-app-credential`, double-check:
   - SHA fingerprints are added correctly in Firebase Console
   - You're using the **release keystore** (not debug keystore)
   - The package name matches: `com.example.zztherapy`

---

## ⚠️ Important: Play App Signing (Google Re-signs Your App)

If you enable **Play App Signing** in Google Play Console (which Google recommends), Google will **re-sign your app** with their own certificate after you upload it.

### What This Means:

- Your **upload keystore** SHA fingerprints (from Step 2) are used for **uploading** to Play Console
- But the **actual app** users download is signed with Google's **app signing certificate**
- You need to add **both** sets of fingerprints to Firebase

### How to Get Play App Signing Certificate Fingerprints:

1. Upload your app to Play Console (Internal Testing or Production)
2. Go to **Play Console** → **Setup** → **App integrity** → **App signing**
3. Find the **"App signing key certificate"** section
4. Copy the **SHA-1** and **SHA-256** fingerprints shown there
5. Add these to Firebase Console (same steps as Step 3)

**Important**: Add **both**:
- Your **upload keystore** fingerprints (for local testing)
- Google's **app signing certificate** fingerprints (for production Play Store users)

---

## Troubleshooting

### Error: `app-not-authorized`

**Cause**: SHA fingerprints not added, or wrong keystore used.

**Fix**:
1. Verify fingerprints are added in Firebase Console
2. Ensure you're using the **release keystore** (not debug)
3. Re-download `google-services.json` if needed

### Error: `invalid-app-credential`

**Cause**: Package name mismatch or wrong Firebase project.

**Fix**:
1. Verify package name in `android/app/build.gradle.kts` matches Firebase Console
2. Ensure you're adding fingerprints to the **correct Firebase project**

### Error: `captcha-check-failed`

**Cause**: Play Integrity API failing (often due to missing SHA fingerprints).

**Fix**:
1. Add SHA-1 and SHA-256 fingerprints
2. Wait a few minutes for Firebase to propagate changes
3. Rebuild and test

### Still Not Working?

1. **Double-check keystore path**: Ensure `key.properties` points to the correct keystore file
2. **Verify package name**: Must be exactly `com.example.zztherapy` (no `.dev` suffix in release)
3. **Check Firebase project**: Ensure you're using the correct Firebase project (`matchvibe-d55f9`)
4. **Wait for propagation**: Firebase changes can take 5-10 minutes to propagate

---

## Quick Reference Commands

### Extract SHA fingerprints:
```powershell
keytool -list -v -keystore .\keystore\upload-keystore.jks -alias upload
```

### Build release APK (for testing):
```powershell
flutter build apk --release
```

### Build release App Bundle (for Play Store):
```powershell
flutter build appbundle --release
```

---

## Summary Checklist

- [ ] Generated release keystore (`upload-keystore.jks`)
- [ ] Extracted SHA-1 fingerprint from keystore
- [ ] Extracted SHA-256 fingerprint from keystore
- [ ] Added SHA-1 to Firebase Console → Android app (`com.example.zztherapy`)
- [ ] Added SHA-256 to Firebase Console → Android app (`com.example.zztherapy`)
- [ ] (If using Play App Signing) Added Google's app signing certificate fingerprints
- [ ] Built release APK/Bundle and tested phone auth

Once all fingerprints are added, your Phone Auth (OTP) flow should work reliably in release builds! 🎉
