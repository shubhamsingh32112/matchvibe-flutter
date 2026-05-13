# Local dev: backend, ADB tunnels, and Windows TLS

## Phone → backend on port 3000 (ADB)

```powershell
powershell -ExecutionPolicy Bypass -File D:\zztherapy\frontend\setup-adb-tunnels.ps1
```

Or:

```powershell
& "D:\zztherapy\frontend\setup-adb-tunnels.ps1"
```

## Windows TLS (AVG / antivirus HTTPS scanning)

If **Gradle** fails with `PKIX path building failed` or **Node** logs `unable to verify the first certificate`, AVG (or similar AV) is intercepting HTTPS. This also breaks **creator gallery uploads** (Cloudflare API).

### One-time fix (automated)

```powershell
powershell -ExecutionPolicy Bypass -File D:\zztherapy\scripts\windows-trust-dev-ca.ps1
```

This exports the AVG root CA, installs it in Windows, refreshes `frontend/android/certs/dev-truststore.jks`, and stops Gradle daemons.

### Backend `.env` (local only)

```env
NODE_ENV=development
LOAD_TEST_DNS_SERVERS=8.8.8.8,8.8.4.4
NODE_EXTRA_CA_CERTS=D:\zztherapy\dev-certs\intercept-root.pem
```

Start backend with **`npm run dev`** (uses `backend/scripts/dev.ps1` so `NODE_EXTRA_CA_CERTS` is set before Node starts).

**Success:** logs show `MongoDB connected successfully` and `Firebase push notifications configured on Stream` (no TLS error).

### Flutter Android build

[`frontend/android/gradle.properties`](android/gradle.properties) points at the local truststore:

```properties
systemProp.javax.net.ssl.trustStore=D:\\zztherapy\\frontend\\android\\certs\\dev-truststore.jks
systemProp.javax.net.ssl.trustStorePassword=changeit
```

Then:

```powershell
cd D:\zztherapy\frontend\android
.\gradlew.bat --stop
cd ..
flutter clean
flutter pub get
flutter run
```

### Alternative

Disable **Scan encrypted connections** / HTTPS inspection in AVG, restart PC, and retry without the truststore steps.

**Do not use in production:** `NODE_TLS_REJECT_UNAUTHORIZED=0`
