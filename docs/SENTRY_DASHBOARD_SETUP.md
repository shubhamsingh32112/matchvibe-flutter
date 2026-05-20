# Sentry dashboard setup (yagati / flutter)

Match Vibe already includes a full Sentry integration. Use this guide to connect the **Sentry dashboard project** (`yagati` → `flutter`) and complete verification.

**Do not re-run the wizard** unless you want it to overwrite `main.dart` — configuration is already in `lib/core/services/sentry_service.dart` and `lib/main.dart`.

---

## 1. Copy DSN into environment

1. Open [Sentry](https://sentry.io) → **yagati** → project **flutter** → **Settings** → **Client Keys (DSN)**.
2. Paste into `frontend/.env.production`:

```env
SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>
```

3. Keep `SENTRY_DSN` **empty** in `.env.development` for day-to-day debug (no production noise).

Optional CI override:

```bash
flutter build appbundle --release \
  --dart-define=SENTRY_DSN=https://...
```

---

## 2. CI / symbol upload (optional)

Set in your pipeline or shell (never commit the auth token):

| Variable | Value |
|----------|--------|
| `SENTRY_AUTH_TOKEN` | User auth token (releases + debug files) |
| `SENTRY_ORG` | `yagati` |
| `SENTRY_PROJECT` | `flutter` |

Android defaults are also in `android/sentry.properties`.

Release build + upload:

```bash
cd frontend
flutter build appbundle --release \
  --split-debug-info=build/app/outputs/symbols \
  --obfuscate
./scripts/sentry_release_upload.sh
```

---

## 3. Verify setup (dashboard “Verify” step)

### Option A — Release build (recommended)

```bash
cd frontend
# Ensure .env.production has SENTRY_DSN
flutter run --release
```

Open **Account Settings** → **Verify Sentry Setup**. This throws the intentional `StateError` from the Sentry docs; the event should appear under **Issues** in project **flutter**.

### Option B — Debug with reporting enabled

```bash
flutter run --dart-define=SENTRY_ALLOW_DEBUG_REPORTING=true
```

Put a **temporary** DSN in `.env.development` for that session only, then use **Verify Sentry Setup** in Account Settings.

### Option C — Wizard (Windows)

Only if starting fresh on another clone:

```powershell
cd frontend
$downloadUrl = "https://github.com/getsentry/sentry-wizard/releases/download/v4.0.1/sentry-wizard-win-x64.exe"
Invoke-WebRequest $downloadUrl -OutFile sentry-wizard.exe
./sentry-wizard.exe -i flutter --saas --org yagati --project flutter
```

This repo is already patched; prefer manual DSN + verify button.

---

## 4. What is already configured in code

| Item | Location |
|------|----------|
| SDK packages | `pubspec.yaml` — `sentry_flutter`, `sentry_dio` |
| Init + scrubbing + dedup | `lib/core/services/sentry_service.dart` |
| App wrapper | `lib/main.dart` — `SentryWidgetsFlutterBinding`, `SentryWidget` |
| Org / project slugs | `SentryService.orgSlug` / `projectSlug`, `android/sentry.properties` |
| Distributed tracing targets | API + socket hosts from `.env` in `tracePropagationTargets` |
| Verify button | Account Settings (debug/profile only) |
| Android ProGuard / mapping | `android/app/build.gradle.kts` |
| Dart + iOS symbols | `scripts/sentry_release_upload.sh` |

---

## 5. Additional Sentry dashboard steps

- **Upload debug symbols** — use release build flags + `sentry_release_upload.sh` (see above).
- **Distributed tracing** — backend must return `sentry-trace` / `baggage` headers for full cross-service traces.
- **Git integration** — connect repo in Sentry for suspect commits and PR comments.
- **Structured logs** — optional future; errors + breadcrumbs are already sent.

---

## 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Verify button shows a toast | Set `SENTRY_DSN`; for debug add `SENTRY_ALLOW_DEBUG_REPORTING=true` or use `--release` |
| No events in Sentry | Confirm release build, non-empty DSN, check correct project **flutter** |
| Events lack stack traces | Run symbol upload script after release build |
| Debug floods production | Keep `.env.development` `SENTRY_DSN` empty |

See also: [SENTRY_INTEGRATION_IMPLEMENTATION.md](SENTRY_INTEGRATION_IMPLEMENTATION.md), [FLUTTER_FRONTEND_COMPREHENSIVE.md](FLUTTER_FRONTEND_COMPREHENSIVE.md) §26.
