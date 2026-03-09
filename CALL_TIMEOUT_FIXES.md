# Call Timeout & Late Pickup Fixes

**Date:** 2026-02-28

## Summary

Fixed call connection timeout issues when:
1. Creator picks up late (e.g., 6 seconds) — user was getting "Connection timed out" before WebRTC could establish
2. Creator doesn't pick up — user got generic timeout; creator stayed on incoming call screen

## Changes Made

### 1. Two-Phase Watchdog (User / Outgoing Calls)

**File:** `lib/features/video/controllers/call_connection_controller.dart`

- **Phase 1 — Ring (15s):** Creator must accept within 15 seconds
  - If timeout → "Creator didn't pick up. Please try again later."
  - Failure reason: `creatorNotPickedUp`

- **Phase 2 — Join (30s):** After creator accepts, 30 seconds for WebRTC to establish
  - If timeout → "Connection timed out. Please try again."
  - Failure reason: `joinTimeout`

- When status transitions to "Connecting" (creator accepted), the ring watchdog is cancelled and the join-phase watchdog (30s) is started.

### 2. Creator Didn't Pick Up → Toast on Home

- Instead of a full-page failed view, we navigate directly to home
- A floating snackbar/toast shows: "Creator is busy"
- User stays on the home screen and can tap another creator to retry

### 3. Creator Side — Incoming Call Ring Timeout (15s)

**File:** `lib/features/video/widgets/incoming_call_listener.dart`

- If creator doesn't accept or reject within 15 seconds, the incoming call overlay auto-dismisses
- Stops ringtone and clears the overlay
- Matches user-side timeout — both parties see the call end

### 4. Video Call Screen Failed View

**File:** `lib/features/video/screens/video_call_screen.dart`

- Added handling for `creatorNotPickedUp` with appropriate title and "Try Again" button
- `joinTimeout` and `creatorNotPickedUp` now show distinct, user-friendly messages

## Timeout Constants

| Constant              | Value | Purpose                                      |
|-----------------------|-------|----------------------------------------------|
| `_ringTimeoutSeconds` | 15    | Creator must accept within 15s               |
| `_joinTimeoutSeconds` | 30    | WebRTC connection after creator accepts     |

## Flow Summary

**User initiates call:**
1. Ring phase starts (15s timer)
2. Creator accepts → status "Connecting" → join phase starts (30s timer)
3. CallStatusConnected → cancel watchdog, start billing
4. If ring timeout (15s) before accept → creatorNotPickedUp
5. If join timeout (30s) after accept → joinTimeout

**Creator receives call:**
1. Incoming overlay shows, 15s ring timeout starts
2. Creator accepts → overlay dismissed, controller takes over
3. Creator rejects → overlay dismissed
4. If 15s passes with no action → overlay auto-dismisses (caller gave up)
