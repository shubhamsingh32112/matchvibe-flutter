# Meta App Events (Android)

Match Vibe logs Meta standard App Events on **Android only** via [`facebook_app_events`](https://pub.dev/packages/facebook_app_events) and a single facade: `lib/core/services/meta_app_events_service.dart`.

Automatic **App Install** and **App Launch** are collected by the Facebook SDK when credentials are configured. **Purchase** is logged manually because checkout uses Razorpay web, not Google Play Billing.

## Credentials

### 1. Native SDK (`android/facebook.properties`)

Copy the example file and fill in values from [Meta for Developers](https://developers.facebook.com/) → your app → **Settings → Basic** (App ID) and **Advanced → Security** (Client token).

```bash
cp android/facebook.properties.example android/facebook.properties
```

`android/facebook.properties` is gitignored.

### 2. Dart gating (`.env` / `--dart-define`)

Add to `.env.development` / `.env.production`:

```
META_APP_ID=your_app_id
META_CLIENT_TOKEN=your_client_token
```

CI/release override:

```bash
flutter build apk --release \
  --dart-define=META_APP_ID=... \
  --dart-define=META_CLIENT_TOKEN=...
```

Events are sent only when:

- Platform is Android
- `META_APP_ID` is set (env or dart-define)
- **Release build**, or debug with `--dart-define=META_ALLOW_DEBUG_EVENTS=true`

## Event hooks

| Meta event | Where it fires |
|------------|----------------|
| App Install / Launch | Facebook SDK (automatic) |
| Complete registration | `auth_provider.dart` — `createdNow == true` after login |
| Complete tutorial | `home_screen.dart` — onboarding permissions accepted |
| View content | `home_user_grid_card.dart` — creator profile opened |
| Add to cart | `wallet_checkout_launcher.dart` — before checkout API (when `priceInr` known) |
| Initiate checkout | `wallet_checkout_launcher.dart` — after `POST /payment/web/initiate` |
| Purchase | `app_lifecycle_wrapper.dart` — wallet deep link `status=success` (uses pending checkout + `sessionId`) |
| Rate | `support_service.dart` — post-call feedback submitted |
| Contact | `support_service.dart` — support ticket created |
| Unlock achievement | `creator_task_service.dart` — task reward claimed |
| Spend credits | `chat_screen.dart` (paid message), `call_billing_provider.dart` (call settled) |
| Customize product | `gender_selection_screen.dart`, `edit_profile_screen.dart` — profile saved |
| Submit application | `referral_service.dart` — referral / agency apply success |

Events **not** implemented (no matching product flow): Search, Subscribe, Start trial, Add payment info, Donate, Schedule, Find location, Add to wishlist.

## Purchase flow (Razorpay)

1. User taps coin pack → optional **AddToCart** (if `priceInr` passed).
2. `initiateWebCheckout` returns `sessionId`, `packageId`, `priceInr`, `coins` → **InitiateCheckout** + pending checkout stored in memory.
3. User pays on website → deep link `zztherapy://wallet?status=success&...` → **Purchase** (deduped by `sessionId`).

Backend already returns `sessionId` from `POST /payment/web/initiate`.

## Testing

### Debug session

```bash
# Requires META_APP_ID in .env.development and android/facebook.properties
flutter run --dart-define=META_ALLOW_DEBUG_EVENTS=true
```

Optional verbose SDK logging:

```bash
flutter run --dart-define=META_ALLOW_DEBUG_EVENTS=true --dart-define=META_APP_EVENTS_DEBUG=true
```

### Meta App Ads Helper

1. [App Ads Helper](https://developers.facebook.com/tools/app-ads-helper/)
2. Select your app → **Test App Events**
3. Run the app on a device/emulator and trigger flows (login, profile, checkout, etc.)
4. Confirm events appear on the helper page in real time

### Release smoke test

```bash
flutter build apk --release
```

Install on a physical device; confirm no crash on cold start and events in **Events Manager** (may take a few minutes).

## Dashboard

In Meta App Dashboard → **Basic → Settings → Android**, keep automatic event logging enabled for Install/Launch. Automatic IAP logging has no effect for Razorpay; purchases are manual only.

## Troubleshooting

| Issue | Check |
|-------|--------|
| No events in debug | Add `META_ALLOW_DEBUG_EVENTS=true` and `META_APP_ID` in `.env` |
| Native SDK not initializing | `android/facebook.properties` present and valid |
| Duplicate Purchase | Pending checkout + `sessionId` dedupe; avoid replaying same deep link |
| ProGuard crash in release | `android/app/proguard-rules.pro` Facebook keep rules |
