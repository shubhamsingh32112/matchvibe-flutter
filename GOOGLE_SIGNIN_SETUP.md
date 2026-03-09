# Google Sign-In Setup

The app now uses **Google Sign-In only** (phone/OTP login has been commented out).

## Firebase Console Setup

1. **Enable Google Sign-In Provider**
   - Go to [Firebase Console](https://console.firebase.google.com) → Your Project
   - **Authentication** → **Sign-in method**
   - Click **Google** → Enable → Save

2. **Configure OAuth Consent (Web)**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Select your Firebase project
   - **APIs & Services** → **OAuth consent screen**
   - Configure app name, support email, developer contact

3. **Create OAuth 2.0 Credentials**
   - **APIs & Services** → **Credentials**
   - **Create Credentials** → **OAuth client ID**
   - Application type: **Android** and **iOS** (create separate for each)
   - For Android: Add your app's package name and SHA-1 certificate fingerprint
   - For iOS: Add your iOS bundle ID

4. **Add SHA-1/SHA-256 (Android)**
   - Run: `cd android && ./gradlew signingReport` (or use `keytool` for release)
   - Add debug and release fingerprints to Firebase: Project Settings → Your Apps

## Platform-Specific

### Android
- `google-services.json` is already in `android/app/`
- Ensure `minSdkVersion` is at least 19 for Google Sign-In

### iOS
- Add URL scheme in `ios/Runner/Info.plist` for Google Sign-In callback
- Add `GoogleService-Info.plist` to the project

## Re-enabling Phone Login

To restore phone/OTP login:

1. Uncomment the phone implementation in `lib/features/auth/providers/auth_provider.dart`
2. Restore the original `login_screen.dart` (phone field + Get OTP button)
3. Restore the `/otp` route in `lib/app/router/app_router.dart` to use `OtpScreen`
4. Ensure `intl_phone_field` is in `pubspec.yaml`
