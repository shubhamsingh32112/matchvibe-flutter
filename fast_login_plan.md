# Fast Login — Implementation Plan

**Goal:** Add Fast Login (device-based, no Google) alongside Google Sign-In. All users still get a Firebase UID so Stream Chat, Stream Video, sockets, call IDs, and quotas work unchanged.

**Scale targets:** 1000 users/day, 200 creators. All changes backward compatible and production-ready.

**Status:** ✅ Implemented. See `fast_login_summary.md` for verification and production checklist.

---

## Architecture (unchanged identity model)

```
Fast Login flow:
  Flutter (deviceFingerprint + installId)
    → POST /auth/fast-login (no Bearer token)
    → Backend: find or create Firebase custom user + Mongo User
    → Response: { firebaseCustomToken }
  Flutter: signInWithCustomToken(firebaseCustomToken)
    → Firebase authStateChanges fires
    → _syncUserToBackend() → POST /auth/login (Bearer <id-token>)
    → Existing login flow continues (Stream, sockets, etc.)
```

Google users: no change. Fast Login users: get a Firebase UID from a backend-created custom user; everything else is identical.

---

## Phase 1 — Backend

### Step 1.1 — User schema (backward compatible)

**File:** `backend/src/modules/user/user.model.ts`

- Add optional fields (existing users have none; treat as Google):
  - `authProvider?: 'google' | 'fast'` (optional)
  - `deviceFingerprint?: string` (optional, indexed for lookup)
  - `installId?: string` (optional)
- Do **not** add a separate `freeTokensClaimed`; use existing `welcomeBonusClaimed` (one welcome bonus per user).
- Indexes:
  - `firebaseUid` (existing unique)
  - `deviceFingerprint` (sparse index, for fast-login lookup)
- Migration: no data migration; new fields optional.

### Step 1.2 — Fast-login endpoint

**Route:** `POST /api/v1/auth/fast-login`  
**Auth:** None (no Bearer token).  
**Rate limit:** 10 requests per minute per IP (unauthenticated). Scalable: 1000 users/day ≈ 0.7/min average; peak ~10–20/min across many IPs; 10/min per IP limits abuse from NAT/shared networks.

**Request body:**

```json
{
  "deviceFingerprint": "string (required)",
  "installId": "string (required)"
}
```

**Logic (auth.controller.ts):**

1. Validate `deviceFingerprint` and `installId` (non-empty, max lengths).
2. Find user: `User.findOne({ deviceFingerprint })`.
3. If user exists:
   - Generate Firebase custom token: `admin.auth().createCustomToken(user.firebaseUid)`.
   - Return `{ success: true, data: { firebaseCustomToken } }`.
4. If user does not exist:
   - Create Firebase user: `admin.auth().createUser({ uid: undefined })` (let Firebase generate UID) or use a deterministic UID from a hash of deviceFingerprint+installId to avoid orphaned Firebase users on Mongo failure.
   - Create User in Mongo: `firebaseUid`, `deviceFingerprint`, `installId`, `authProvider: 'fast'`, `role: 'user'`, `coins: 0`, `welcomeBonusClaimed: false`, etc. (same defaults as login controller).
   - Generate custom token for new `firebaseUid`.
   - Return `{ success: true, data: { firebaseCustomToken } }`.
5. Errors: 400 validation, 429 rate limit, 500 server.

**Deterministic UID:** Use a stable UID for the same device so that retries don’t create multiple Firebase users. Implemented: `fast_` + first 22 chars of SHA256(deviceFingerprint:installId) (27 chars; Firebase UID max 128).

**Race-condition handling:** Firebase `auth/uid-already-exists` → find User, return token. Mongo E11000 → find User, return token.

### Step 1.3 — Login controller compatibility

**File:** `backend/src/modules/auth/auth.controller.ts`

- No change. Login still: verify Firebase token → find/create User by `firebaseUid`. Fast Login users are created in fast-login; login will only find them and return payload.

### Step 1.4 — Rate limiting

- Apply a strict rate limit to `POST /auth/fast-login` (e.g. 10/min per IP) via existing or new middleware so 1000 users/day is safe and abuse is limited.

---

## Phase 2 — Flutter

### Step 2.1 — Dependencies

**File:** `frontend/pubspec.yaml`

- Add:
  - `device_info_plus: ^11.0.0` (device fingerprint)
  - `flutter_secure_storage: ^9.2.2` (install ID)
  - `uuid: ^4.5.1` (generate install ID)

### Step 2.2 — Device fingerprint service

**New file:** `frontend/lib/core/services/device_fingerprint_service.dart`

- Use `device_info_plus`:
  - Android: `AndroidDeviceInfo.id` (or fingerprint if available).
  - iOS: `IosDeviceInfo.identifierForVendor`.
- Return a stable string per device; handle errors (return fallback or throw).

### Step 2.3 — Install ID service

**New file:** `frontend/lib/core/services/install_id_service.dart`

- Use `flutter_secure_storage` with key e.g. `install_id`.
- If no value: generate `Uuid().v4()`, write, return. Else read and return.
- One install ID per app install.

### Step 2.4 — Auth provider: Fast Login

**File:** `frontend/lib/features/auth/providers/auth_provider.dart`

- Add `signInWithFastLogin()`:
  1. Get deviceFingerprint and installId (from services above).
  2. Call `POST /auth/fast-login` (no auth header) with `{ deviceFingerprint, installId }`.
  3. On success: `FirebaseAuth.instance.signInWithCustomToken(data.firebaseCustomToken)`.
  4. Firebase will fire `authStateChanges`; existing `_syncUserToBackend` runs (same as Google).
- Do not call `/auth/login` explicitly; it’s called inside `_syncUserToBackend` after token is stored.
- Errors: network, 4xx/5xx → set state error, no throw if you show in UI.

### Step 2.5 — Login screen UI

**File:** `frontend/lib/features/auth/screens/login_screen.dart`

- Order:
  1. **Fast Login** (primary: one tap, no account picker).
  2. **Continue with Google** (unchanged).
- Terms checkbox applies to both.
- Fast Login button: same style as Google (outlined or filled), label e.g. “Continue with Fast Login” or “Try without account”.
- Loading: disable both buttons and show loading on the pressed button during fast-login + custom token sign-in.

### Step 2.6 — API client

- Fast-login request must **not** attach the Bearer token (endpoint is unauthenticated). Use a dedicated call (e.g. `ApiClient().post('/auth/fast-login', ...)` without injecting token for this path, or a one-off Dio/HTTP call without interceptors). Ensure `ApiClient` does not add Authorization for this single request (e.g. optional parameter or separate method).

---

## Phase 3 — Production readiness

### Step 3.1 — Backend

- Logging: log fast-login attempts (no PII); log new user creation (firebaseUid, authProvider).
- Rate limit: 10/min per IP for `POST /auth/fast-login`.
- Validation: trim and length limits on deviceFingerprint and installId (e.g. max 256 chars each).

### Step 3.2 — Flutter

- Handle missing permissions/errors for device info (fallback or clear error message).
- No PII in logs (no device fingerprint in production logs if sensitive).

### Step 3.3 — Backward compatibility

- Existing Google users: no schema change required; `authProvider` undefined → treat as Google.
- Existing login, Stream, sockets, call IDs, quotas: no changes; Fast Login users have Firebase UID like everyone else.

---

## Phase 4 — Optional future: Link Google

- **Not in this implementation.** Endpoint `POST /auth/link-google` (authenticated with Firebase): Backend verifies Firebase ID token, then links Google credential to that Firebase UID. Flow: Fast Login user → later signs in with Google → same Firebase UID and data.
- **Benefits:** Account recovery, multi-device use, long-term retention.

---

## Files to create/change summary

| Layer   | Action | File |
|--------|--------|------|
| Backend | Modify | `user.model.ts` (add authProvider, deviceFingerprint, installId) |
| Backend | Modify | `auth.controller.ts` (add fastLogin) |
| Backend | Modify | `auth.routes.ts` (POST /fast-login + rate limit) |
| Flutter | Add dep | `pubspec.yaml` (device_info_plus, flutter_secure_storage, uuid) |
| Flutter | Create | `device_fingerprint_service.dart` |
| Flutter | Create | `install_id_service.dart` |
| Flutter | Modify | `auth_provider.dart` (signInWithFastLogin) |
| Flutter | Modify | `login_screen.dart` (Fast Login button, order) |
| Flutter | Modify | `api_client.dart` or use one-off request for fast-login (no token) |

---

## Execution order

1. Backend schema + fast-login controller + route + rate limit.
2. Flutter deps → device + install ID services → auth provider → login screen.
3. Manual test: Fast Login → check Firebase UID → login → Stream/sockets/calls unchanged.
4. Write `fast_login_summary.md` with what was implemented and how to verify.

---

## Scalability (1000 users/day, 200 creators)

| Concern | Implementation | Notes |
|--------|----------------|-------|
| Rate limit | 10/min per IP | Sufficient for peak; users behind NAT may see 429 on rapid retries. |
| Mongo indexes | firebaseUid (unique), deviceFingerprint (sparse) | O(1) lookups. |
| Firebase | createUser/createCustomToken | Idempotent with race handling. |
| Stream/sockets | No change | Fast Login users use same Firebase UID flow. |
| Creators | No change | 200 creators unaffected; auth is user-only. |
