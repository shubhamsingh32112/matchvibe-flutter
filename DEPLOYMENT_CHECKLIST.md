# 🚀 Final Deployment Checklist

You've completed the major setup steps! Here's what's left to get your app ready for Play Store.

## ✅ Completed Steps

- [x] Generated release keystore (`upload-keystore.jks`)
- [x] Extracted SHA-1 and SHA-256 fingerprints
- [x] Added SHA fingerprints to Firebase Console (`com.example.zztherapy`)
- [x] Environment files configured (`.env.development` and `.env.production`)

---

## 📋 Remaining Steps

### Step 1: Create `android/key.properties` File

Create `frontend/android/key.properties` with your keystore credentials:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../keystore/upload-keystore.jks
```

**Replace:**
- `YOUR_KEYSTORE_PASSWORD` → The password you entered when creating the keystore
- `YOUR_KEY_PASSWORD` → Usually the same as keystore password (or the key password you set)

**Important:** This file is already in `.gitignore`, so it won't be committed to git.

---

### Step 2: Verify Environment Files

Make sure your `.env.production` file has **production backend URLs**:

```env
API_BASE_URL=https://your-production-backend.com/api/v1
SOCKET_URL=https://your-production-backend.com
WEBSITE_BASE_URL=https://your-production-website.com
STREAM_API_KEY=d536t7g4q75v
```

**Note:** Replace with your actual production URLs (not `localhost` or `192.168.x.x`).

---

### Step 3: Test Release Build Locally

Build a release APK to test on a real device:

```powershell
cd frontend
flutter clean
flutter pub get
flutter build apk --release
```

The APK will be at: `frontend/build/app/outputs/flutter-apk/app-release.apk`

**Install on a real Android device** (not emulator) and test:
- [ ] App launches without crashes
- [ ] Phone number login (OTP) works
- [ ] Backend API calls work (verify URLs are correct)
- [ ] No `app-not-authorized` or `invalid-app-credential` errors

---

### Step 4: Build App Bundle for Play Store

Once testing passes, build the App Bundle:

```powershell
cd frontend
flutter build appbundle --release
```

The `.aab` file will be at: `frontend/build/app/outputs/bundle/release/app-release.aab`

**This is what you upload to Google Play Console.**

---

### Step 5: Play Store Setup (When Ready)

1. **Create Play Console account** (if you don't have one)
   - Go to [Google Play Console](https://play.google.com/console)
   - Pay the one-time $25 registration fee

2. **Create new app**
   - App name: "Match Vibe" (or your chosen name)
   - Default language: English (or your choice)
   - App or game: App
   - Free or paid: Your choice

3. **Upload App Bundle**
   - Go to **Production** → **Create new release**
   - Upload `app-release.aab`
   - Fill in release notes

4. **Complete Store Listing**
   - App icon, screenshots, description
   - Privacy policy URL (required)
   - Content rating questionnaire

5. **App Content**
   - Privacy policy (required)
   - Data safety form

6. **App Access**
   - If your app requires login, mark it appropriately

7. **Submit for Review**

---

## 🔍 Pre-Deployment Verification

Before submitting to Play Store, verify:

### Code Checklist
- [ ] No hardcoded development URLs in code (all use `.env` files)
- [ ] No `debugPrint` statements in production code (they're gated behind `kDebugMode`)
- [ ] No test/placeholder data
- [ ] Error handling is user-friendly

### Configuration Checklist
- [ ] `android/key.properties` exists with correct passwords
- [ ] `.env.production` has production backend URLs
- [ ] SHA fingerprints added to Firebase Console (`com.example.zztherapy`)
- [ ] Firebase `google-services.json` is present and correct
- [ ] App version number is set correctly (`pubspec.yaml`)

### Testing Checklist
- [ ] Release APK installs and runs on real device
- [ ] Phone auth (OTP) works in release build
- [ ] Backend API connectivity works
- [ ] All major features work (chat, video calls, wallet, etc.)
- [ ] No crashes or critical errors

---

## 🐛 Common Issues & Fixes

### Issue: Build fails with "keystore not found"

**Fix:** Ensure `android/key.properties` exists and `storeFile` path is correct:
```properties
storeFile=../keystore/upload-keystore.jks
```

### Issue: Phone auth fails with `app-not-authorized`

**Fix:** 
- Verify SHA fingerprints are added to **production app** (`com.example.zztherapy`)
- Wait 5-10 minutes for Firebase to propagate changes
- Rebuild and test

### Issue: Backend API calls fail

**Fix:**
- Check `.env.production` has correct production URLs
- Ensure backend server is running and accessible
- Verify URLs use `https://` (not `http://`) for production

### Issue: App crashes on launch

**Fix:**
- Check Firebase initialization (ensure `google-services.json` is present)
- Verify all environment variables are set in `.env.production`
- Check logs: `flutter logs` or Android Studio Logcat

---

## 📝 Quick Reference Commands

### Build release APK (for testing):
```powershell
cd frontend
flutter build apk --release
```

### Build release App Bundle (for Play Store):
```powershell
cd frontend
flutter build appbundle --release
```

### Check app version:
```powershell
cd frontend
flutter pub get
# Check version in pubspec.yaml: version: 1.0.0+2
```

### Extract SHA fingerprints (if needed again):
```powershell
cd frontend
keytool -list -v -keystore .\keystore\upload-keystore.jks -alias upload
```

---

## 🎉 You're Almost There!

Once you complete Step 1 (`key.properties`) and test the release build (Step 3), you'll be ready to upload to Play Store!

**Next immediate action:** Create `frontend/android/key.properties` file with your keystore passwords.
