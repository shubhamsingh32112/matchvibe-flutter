# Android release signing (Keystore) — Windows guide

This project is configured to load release signing from:

- `frontend/android/key.properties` (not committed)
- A `.jks` keystore file path referenced by `storeFile` (not committed)

## 1) Generate a keystore (upload key)

From `frontend/`:

```powershell
mkdir keystore -Force

# Create a new keystore (you will be prompted for passwords + certificate info)
keytool -genkeypair -v `
  -keystore .\keystore\upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

If `keytool` is not found, install a JDK (or use Android Studio's embedded JDK) and ensure `keytool` is on your PATH.

## 2) Create `android/key.properties`

Create `frontend/android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../keystore/upload-keystore.jks
```

## 3) Build a signed release

From `frontend/`:

```powershell
flutter clean
flutter pub get

# Recommended for Play Store:
flutter build appbundle --release

# Or APK:
flutter build apk --release
```

## Notes

- Do **not** commit `key.properties` or the `.jks` file.
- Losing the keystore means you cannot update the app in Play Store later.

## Phone Auth (OTP) in Release — SHA fingerprints still matter

Even if you do **not** use Google Sign-In, **Firebase Phone Authentication on Android** uses Play Integrity / reCAPTCHA behind the scenes.
For the smoothest OTP flow in **release**, add your **release signing** SHA-1 and SHA-256 to Firebase Console.

**📖 See detailed step-by-step guide:** [`FIREBASE_SHA_FINGERPRINTS.md`](./FIREBASE_SHA_FINGERPRINTS.md)

### Quick Summary:

1. Extract SHA fingerprints from your keystore:
   ```powershell
   keytool -list -v -keystore .\keystore\upload-keystore.jks -alias upload
   ```

2. Add SHA-1 and SHA-256 to Firebase Console:
   - Firebase Console → Project Settings → Your apps → Android (`com.example.zztherapy`) → **SHA certificate fingerprints**

3. If using Play App Signing, also add Google's app signing certificate fingerprints from Play Console.

**Full instructions:** See [`FIREBASE_SHA_FINGERPRINTS.md`](./FIREBASE_SHA_FINGERPRINTS.md) for complete details.
