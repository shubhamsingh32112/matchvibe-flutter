# Stream Video Integration Guide

## Overview

This module implements 1-on-1 video calling between users and creators using Stream Video SDK.

## Components

### Services
- **`video_service.dart`**: Backend API for Stream Video JWT (`POST /api/v1/video/token`) only
- **`call_service.dart`**: Call creation via **Stream SDK** (`getOrCreate`), join, leave — the backend learns calls from Stream webhooks + billing events, not from a REST “initiate” endpoint

### Providers
- **`stream_video_provider.dart`**: Stream Video client state management

### Screens
- **`video_call_screen.dart`**: Active call UI with restrictions (no screen sharing, no recording)

### Widgets
- **`incoming_call_widget.dart`**: UI for incoming call notification
- **`incoming_call_listener.dart`**: Listens for incoming calls and shows UI automatically

## Usage

### 1. Add IncomingCallListener to App

Wrap your app with `IncomingCallListener` to automatically show incoming call UI:

```dart
// In main.dart or app router
IncomingCallListener(
  child: MaterialApp.router(...),
)
```

### 2. Initiate Call from User Side

When a user taps "Call Creator" button:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../video/services/call_service.dart';
import '../video/providers/stream_video_provider.dart';
import '../video/screens/video_call_screen.dart';

// In your creator card/profile screen
final callService = ref.read(callServiceProvider);
final streamVideo = ref.read(streamVideoProvider);

if (streamVideo == null) {
  // Stream Video not initialized
  return;
}

try {
  // Initiate call
  final call = await callService.initiateCall(
    creatorId: creator.id, // MongoDB ObjectId string
    streamVideo: streamVideo,
  );
  
  // Join the call
  await callService.joinCall(call);
  
  // Navigate to call screen
  if (context.mounted) {
    context.push('/call', extra: call);
  }
} catch (e) {
  // Handle error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to start call: $e')),
  );
}
```

### 3. Add Call Route

Add route for call screen in your router:

```dart
GoRoute(
  path: '/call',
  builder: (context, state) {
    final call = state.extra as Call;
    return VideoCallScreen(call: call);
  },
),
```

### 4. Add Call Button to Creator Card

Example: Add call button to `HomeUserGridCard`:

```dart
// In home_user_grid_card.dart
if (isRegularUser && creator != null)
  Positioned(
    bottom: AppSpacing.lg,
    right: AppSpacing.lg,
    child: FloatingActionButton(
      onPressed: () async {
        // Use call service to initiate call
        final callService = ref.read(callServiceProvider);
        final streamVideo = ref.read(streamVideoProvider);
        
        if (streamVideo == null) return;
        
        try {
          final call = await callService.initiateCall(
            creatorId: creator.id,
            streamVideo: streamVideo,
          );
          await callService.joinCall(call);
          
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoCallScreen(call: call),
              ),
            );
          }
        } catch (e) {
          // Handle error
        }
      },
      child: Icon(Icons.videocam),
    ),
  ),
```

## Features

### ✅ Implemented
- Server-side token generation
- Call initiation with ringing
- Incoming call detection
- Accept/reject call UI
- Active call screen with restrictions
- Background video/audio muting
- Automatic token refresh

### 🔒 Security
- Only users can initiate calls (enforced server-side)
- Exactly 2 participants (user + creator)
- Role-based tokens (user vs call_member)
- Call IDs include a timestamp so each dial attempt is a fresh Stream session

### 🚫 Disabled Features
- Screen sharing (explicitly disabled)
- Recording (not available in call settings)
- Broadcasting (not available in call settings)
- Group calls (max 2 participants enforced)

## Backend Endpoints

- `POST /api/v1/video/token` — Stream Video JWT (required before `StreamVideo` connects)
- Call creation is **not** a backend REST call; use the SDK as in `call_service.dart`

## Configuration

### HD Video Settings

Configure in Stream Dashboard (not in code):
1. Go to https://dashboard.getstream.io
2. Navigate to your app → Video Settings
3. Select "default" call type
4. Set video resolution:
   - Width: 1280
   - Height: 720
   - Bitrate: 2500000

See `STREAM_VIDEO_IMPLEMENTATION.md` for details.

## Error Handling

All services include error handling and logging. Check debug console for:
- `[VIDEO]` - Video service logs
- `[CALL]` - Call service logs
- `[STREAM VIDEO]` - Stream Video SDK logs

## Testing

1. Ensure backend is running
2. Ensure Stream API key is configured in both backend and frontend
3. Login as a user (not creator)
4. Tap call button on a creator card
5. Creator should receive incoming call notification
6. Creator accepts → both join call
7. Creator rejects → call ends
