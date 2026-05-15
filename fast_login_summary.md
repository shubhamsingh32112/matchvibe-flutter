# Fast Login — Implementation Summary

This document summarizes what was implemented for Fast Login and how to verify it. The plan is in `fast_login_plan.md`; the identity model is documented in `LOGIN_SIGNUP_AND_IDS.md`.

---

## What Was Implemented

### Backend (Node.js)

1. **User schema** (`backend/src/modules/user/user.model.ts`)
   - Added optional fields: `authProvider` ('google' | 'fast'), `deviceFingerprint`, `installId` (max 256 chars each).
   - Added sparse index on `deviceFingerprint` for fast-login lookup.
   - Backward compatible: existing users have no value for these fields and are treated as Google.

2. **Fast-login endpoint** (`backend/src/modules/auth/auth.controller.ts`)
   - **Route:** `POST /api/v1/auth/fast-login` (no Bearer token).
   - **Body:** `{ deviceFingerprint: string, installId: string }`.
   - **Logic:**
     - Lookup: single `User.findOne({ $or: [{ deviceFingerprint }, { firebaseUid }] })` (one DB round trip, uses both indexes).
     - If a user exists, a Firebase custom token is generated for their `firebaseUid` and returned.
     - If no user exists: a deterministic Firebase UID is computed (`fast_` + first 22 chars of SHA256(deviceFingerprint:installId)), Firebase custom user is created with that UID (idempotent), and a new Mongo User is created with `authProvider: 'fast'`, same defaults as normal Google signup (`coins: 0`, intro-call credits and onboarding fields per the standard first-login path). Then a custom token for that UID is returned.
   - **Race-condition handling:** Concurrent requests with same deviceFingerprint: Firebase `auth/uid-already-exists` → find User by firebaseUid or deviceFingerprint, return token. Mongo E11000 duplicate key → find User, return token.
   - **Response:** `{ success: true, data: { firebaseCustomToken } }`.
   - Validation: both fields required, non-empty, max 256 chars. Errors: 400 (validation), 429 (rate limit), 500 (server).

3. **Rate limiting** (`backend/src/middlewares/rate-limit.middleware.ts`, `auth.routes.ts`)
   - `fastLoginLimiter`: 10 requests per minute per IP for `POST /auth/fast-login`.
   - Skips when `NODE_ENV=development` and `DISABLE_RATE_LIMIT=true`.

4. **Auth routes** (`backend/src/modules/auth/auth.routes.ts`)
   - Registered `POST /fast-login` with `fastLoginLimiter` and `fastLogin` controller (no `verifyFirebaseToken`).

### Frontend (Flutter)

1. **Dependencies** (`frontend/pubspec.yaml`)
   - `device_info_plus: ^11.0.0` — device fingerprint (Android ID / iOS identifierForVendor).
   - `flutter_secure_storage: ^9.2.2` — secure storage for install ID.
   - `uuid: ^4.5.1` — generate install ID (v4).

2. **Device fingerprint** (`frontend/lib/core/services/device_fingerprint_service.dart`)
   - `DeviceFingerprintService.isFastLoginAllowed()`: Returns `false` on Android emulators (`!isPhysicalDevice` or model/fingerprint/hardware contain sdk|generic|goldfish); requires Google Sign-In. iOS always allowed.
   - `DeviceFingerprintService.getDeviceFingerprint()`: Android uses `androidInfo.id`, iOS uses `iosInfo.identifierForVendor`. Throws on unsupported platform or empty value.

3. **Install ID** (`frontend/lib/core/services/install_id_service.dart`)
   - `InstallIdService.getInstallId()`: reads from secure storage under `install_id`; if missing, generates UUID v4, writes it, returns it. One ID per install.

4. **Auth provider** (`frontend/lib/features/auth/providers/auth_provider.dart`)
   - `signInWithFastLogin()`:
     - Ensures Firebase is initialized.
     - Gets device fingerprint and install ID.
     - Calls `POST /auth/fast-login` with a **one-off Dio** instance (no auth header).
     - On success: `FirebaseAuth.instance.signInWithCustomToken(firebaseCustomToken)`.
     - Firebase `authStateChanges` then triggers the existing `_syncUserToBackend` flow (token storage + `POST /auth/login`), so Stream Chat, Stream Video, sockets, and the rest of the app behave the same as for Google sign-in.
     - On error: sets `state.error` and `isLoading: false`; for Dio errors, uses server `error` message when present.

5. **Login screen** (`frontend/lib/features/auth/screens/login_screen.dart`)
   - **Order:** Fast Login first, then Google.
   - Subtitle: “Sign in with Fast Login or Google to continue.”
   - Fast Login button: “Continue with Fast Login” with flash icon; same terms checkbox and loading behavior as Google.
   - Google button: unchanged, labeled “Continue with Google”.

---

## Backward Compatibility

- **Existing Google users:** No schema migration; `authProvider` (and device fields) are optional. Login and all downstream behavior unchanged.
- **Stream Chat / Stream Video / sockets / call IDs / quotas:** No code changes. Fast Login users get a Firebase UID like everyone else; the same tokens and UIDs are used.
- **Economy / promos:** Fast Login users match normal signup: wallet starts at 0 coins; welcome free-call eligibility follows server rules (`introFreeCallCredits` / `welcomeFreeCallEligible`). There is no separate in-app “claim 30 coins” welcome bonus.

---

## Scale and Production Readiness

### Scalability (1000 users/day, 200 creators)

| Concern | Implementation | Notes |
|--------|----------------|-------|
| Rate limit | 10/min per IP | 1000 users/day ≈ 0.7/min average; peak ~10–20/min across many IPs; sufficient. Users behind same NAT may hit 429 on rapid retries. |
| Mongo indexes | firebaseUid (unique), deviceFingerprint (sparse) | O(1) lookups. |
| Firebase | createUser/createCustomToken | Idempotent with race handling. |
| Creators | No change | 200 creators unaffected; auth is user-only. |

### Security

- Fast-login is unauthenticated but rate-limited; no Bearer token sent.
- Deterministic UID prevents orphaned Firebase users on retries.
- No PII in logs (device fingerprint not logged in production).

### Flutter Best Practices

- Async services (`DeviceFingerprintService`, `InstallIdService`).
- One-off Dio for unauthenticated call (no token injection).
- Error handling with user-facing messages; `kDebugMode` for verbose logs.
- Platform check: Fast Login supported on Android and iOS only.

### Node.js Best Practices

- Input validation (required, trim, max length 256).
- Logging with `logInfo`/`logDebug`/`logError`; no PII in logs.
- Idempotent Firebase user creation with race-condition handling.
- Sparse indexes on optional fields; no migration required.

### Production Checklist

**Backend**
- [ ] Mongo indexes created (firebaseUid unique, deviceFingerprint sparse)
- [ ] Firebase Admin configured (FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL)
- [ ] Rate limit enabled (`DISABLE_RATE_LIMIT` unset or `false` in production)

**Flutter**
- [ ] `API_BASE_URL` correct for production
- [ ] Test on real Android device
- [ ] Test on real iPhone

### Verification (post Fast Login)

- [ ] `firebaseUid` starts with `fast_` (check debug logs)
- [ ] Stream Chat connects
- [ ] Creator list loads
- [ ] Call initiation works

---

## How to Verify

1. **Backend**
   - Start backend; ensure Firebase Admin is configured.
   - `curl -X POST http://localhost:3000/api/v1/auth/fast-login -H "Content-Type: application/json" -d "{\"deviceFingerprint\":\"test-device-1\",\"installId\":\"test-install-1\"}"`
   - Expect `200` and `{ "success": true, "data": { "firebaseCustomToken": "..." } }`.
   - Repeat with same body: same user, same UID, again 200 with a (new) custom token.
   - Send invalid body (e.g. missing field): expect 400. Send >10 requests in a minute from same IP: expect 429.

2. **Flutter**
   - Run app on Android or iOS (Fast Login is only supported on these platforms).
   - Open login screen; accept terms; tap “Continue with Fast Login”.
   - Should sign in and then either go to gender selection (new user) or home (returning). Stream Chat/Video and sockets should work as for Google (e.g. creator list, availability).
   - Tap “Continue with Google” and sign in: should work as before; no regression.

3. **Identity**
   - After Fast Login, in debug logs you should see a Firebase UID starting with `fast_` and a normal login payload (user or creator). Stream and socket code paths use this UID; no separate branches for Fast Login.

---

## Files Touched

| File | Change |
|------|--------|
| `backend/src/modules/user/user.model.ts` | Optional authProvider, deviceFingerprint, installId; index on deviceFingerprint. |
| `backend/src/modules/auth/auth.controller.ts` | New `fastLogin` handler; crypto + getFirebaseAdmin; race-condition handling. |
| `backend/src/modules/auth/auth.routes.ts` | POST /fast-login with fastLoginLimiter. |
| `backend/src/middlewares/rate-limit.middleware.ts` | fastLoginLimiter (10/min per IP). |
| `frontend/pubspec.yaml` | device_info_plus, flutter_secure_storage, uuid. |
| `frontend/lib/core/services/device_fingerprint_service.dart` | New. |
| `frontend/lib/core/services/install_id_service.dart` | New. |
| `frontend/lib/features/auth/providers/auth_provider.dart` | signInWithFastLogin(). |
| `frontend/lib/features/auth/screens/login_screen.dart` | Fast Login button first, Google second; subtitle updated. |
| `frontend/fast_login_plan.md` | Detailed step-by-step plan (updated). |

---

## Implemented Improvements

1. **Secondary device lookup:** Backend finds user by `deviceFingerprint` OR `firebaseUid` (derived hash). Handles edge cases where fingerprint format changes after OS updates.
2. **Emulator detection:** On Android, `androidInfo.isPhysicalDevice` is checked. If false (emulator), Fast Login is disabled and the user must use Google Sign-In. Reduces emulator-farm abuse.

---

## Optional Future Work (Not Done)

- **Link Google** — `POST /auth/link-google` (authenticated): Link a Google credential to an existing Fast Login account. Flow: Fast Login user → later signs in with Google → same Firebase UID. Benefits: account recovery, multi-device use, long-term retention.
