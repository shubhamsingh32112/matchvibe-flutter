# Google Sign-In Setup

The app supports **Fast Login** and **Google Sign-In**. Both use Firebase Auth; the backend finds or creates a user by Firebase UID on `POST /auth/login`.

## Firebase Console

1. **Enable Google provider**
   - Firebase Console → your project → **Authentication** → **Sign-in method**
   - Enable **Google** (turn on, set support email, save)

2. **Project configured via `flutterfire configure`**
   - `lib/firebase_options.dart` (gitignored) contains your Firebase config
   - Backend must have Firebase Admin SDK credentials: `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`

3. **Android: SHA fingerprints**
   - Add your debug and release SHA-1 (and SHA-256 if required) in Firebase Console → Project settings → Your apps → Android app
   - See `FIREBASE_SHA_FINGERPRINTS.md` if you have a separate doc for this

4. **iOS (if you ship iOS)**
   - Add your iOS app bundle ID in Firebase
   - Download `GoogleService-Info.plist` and add to Xcode (flutterfire configure does this)

## App flow

- **Login screen:** User can tap "Continue with Fast Login" or "Continue with Google".
- **Google:** `GoogleSignIn().signIn()` → get ID token → `signInWithCredential(GoogleAuthProvider.credential(...))` → Firebase Auth state updates → `_syncUserToBackend` → `POST /auth/login` with Bearer token → backend finds/creates user by `firebaseUid`.
- **Sign out:** App calls `FirebaseAuth.signOut()` and `GoogleSignIn().signOut()` so next time the user gets the Google account picker.

## Data safety / Play Store

If you collect Google sign-in (email/name), declare it in your app’s Data Safety section and privacy policy as required by Google Play and applicable laws.
