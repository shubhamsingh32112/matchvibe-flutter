# Eazy Talks - Flutter Frontend

Flutter mobile app for Eazy Talks with Firebase authentication and smooth UX.

## Setup

1. **Install Flutter dependencies:**
```bash
cd frontend
flutter pub get
```

2. **Configure Firebase:**
   - Install Firebase CLI: `npm install -g firebase-tools`
   - Run: `flutterfire configure`
   - This will create `lib/firebase_options.dart`

3. **Configure environment (.env):**
   - Copy `.env.example` to `.env.development` and `.env.production`:
     ```bash
     # Linux/macOS
     cp .env.example .env.development && cp .env.example .env.production
     # Windows (PowerShell)
     Copy-Item .env.example .env.development; Copy-Item .env.example .env.production
     ```
   - Edit both files and set your values. Required keys:
     - `API_BASE_URL` (ex: `https://api.yourdomain.com/api/v1`)
     - `SOCKET_URL` (ex: `https://api.yourdomain.com`)
     - `WEBSITE_BASE_URL` (ex: `https://yourdomain.com`)
     - `STREAM_API_KEY` (public key; optional if you keep the default)

4. **Run the app:**
```bash
flutter run
```

## Android Release Signing (Play Store)

Release signing is loaded from `android/key.properties` (ignored by git). See Flutter docs: `https://docs.flutter.dev/deployment/android`.

## Project Structure

```
lib/
├── app/              # App-level configuration
│   ├── router/       # Navigation routes
│   └── widgets/      # Shared app widgets
├── core/             # Core utilities
│   ├── api/          # API client
│   ├── constants/    # App constants
│   ├── theme/        # App theme
│   └── utils/        # Utility functions
├── features/         # Feature modules
│   ├── auth/         # Authentication
│   ├── home/         # Home screen
│   ├── recent/        # Recent screen
│   ├── account/      # Account screen
│   └── user/         # User providers
└── shared/           # Shared components
    ├── models/       # Data models
    └── widgets/      # Reusable widgets
```

## Features

- ✅ Firebase Authentication (Phone + Email)
- ✅ Riverpod state management
- ✅ go_router navigation
- ✅ Skeleton loaders
- ✅ Smooth animations
- ✅ Error handling
- ✅ Persistent navigation bars

## Environment

- Flutter: 3.38.7
- Dart: 3.10.7
