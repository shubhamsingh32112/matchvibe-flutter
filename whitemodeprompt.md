You are a senior Flutter engineer working on a production app.

Your task is to refactor the entire app UI from a dark theme to a clean, premium light theme using:

- Primary base: White (#FFFFFF)
- Secondary base: Beige (#F5F5DC or slightly warmer variants like #F7EFE5)
- Accent: Red (#E53935 or slightly muted #D32F2F)
- Text: Near-black (#1A1A1A) and soft gray (#6B6B6B)

The app currently:
- Uses Material 3
- Uses a dark ColorScheme generated from seed (#9F7AEA)
- Has heavy gradient usage (purple-based)
- Uses surfaceContainerHigh and dark backgrounds extensively
- Uses Stream Chat and Stream Video UI components
- Uses custom components like AppScaffold, AppCard, PrimaryButton

---

## GOAL

Transform the UI into a **consistent, modern light design system** while preserving:
- Component structure
- UX flows
- Role-based behavior (user / creator / admin)

---

## STEP 1 — GLOBAL THEME REFACTOR

Modify `app_theme.dart`:

1. Replace dark theme with light theme:
   - brightness: Brightness.light
   - Remove seed-based purple scheme
   - Define explicit ColorScheme

2. Use this base:

```dart
const ColorScheme lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFD32F2F),
  onPrimary: Colors.white,
  secondary: Color(0xFFF5F5DC),
  onSecondary: Color(0xFF1A1A1A),
  surface: Colors.white,
  onSurface: Color(0xFF1A1A1A),
  error: Color(0xFFD32F2F),
  onError: Colors.white,
  outline: Color(0xFFE0E0E0),
);
Update:
scaffoldBackgroundColor → Colors.white
cardColor → Colors.white
dialogBackgroundColor → Colors.white
Typography:
Keep Montserrat
Ensure all text uses dark colors (no white text unless on red)
STEP 2 — REMOVE DARK GRADIENT DEPENDENCY

File: app_brand_styles.dart

Replace:

Purple gradients → subtle beige/white gradients

Example:

LinearGradient(
  colors: [Color(0xFFFFFFFF), Color(0xFFF7EFE5)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
)

Rules:

NO dark backgrounds anywhere
Gradients should be subtle, not dominant
STEP 3 — COMPONENT REFACTOR RULES

Apply globally:

❌ REMOVE
Colors.black
Colors.white.withOpacity for dark overlays
Purple accents
Dark surfaces like surfaceContainerHigh
✅ REPLACE WITH
Backgrounds → white or beige
Borders → light gray (#E0E0E0)
Elevation → very soft shadows
Accents → red only for CTA / active states
STEP 4 — APP SCAFFOLD

Update AppScaffold:

background → white
remove gradient background usage
add optional subtle beige section backgrounds
STEP 5 — CARDS (AppCard, Grid Cards, Wallet Cards)

Refactor all cards:

background: white
borderRadius: 16
border: 1px solid #ECECEC
shadow: very soft

Text hierarchy:

Title: #1A1A1A
Subtitle: #6B6B6B

Status colors:

Online → green (#2E7D32)
Busy → amber (#F9A825)
Error → red (#D32F2F)
STEP 6 — BUTTON SYSTEM
PrimaryButton:
background: red
text: white
Secondary:
background: beige
text: dark
Outline:
border: red
text: red

No dark buttons anywhere.

STEP 7 — NAVIGATION BAR

Update MainLayout:

background: white
selected icon: red
unselected: gray (#9E9E9E)
remove transparency + gradients
STEP 8 — CHAT THEME (CRITICAL)

Update StreamChatTheme:

own messages → red background, white text
other messages → light beige background
input field → white with border
remove dark containers completely
STEP 9 — VIDEO CALL UI

Currently:

dark overlays
purple gradients

Change to:

Outgoing Call:
background: white + subtle beige gradient
CTA buttons:
Accept → green
Reject → red
In-call:
controls → white translucent cards
text → white only if over video

Remove heavy dark gradients.

STEP 10 — BOTTOM SHEETS

All bottom sheets:

background: white
top radius: 24
remove transparent/dark overlays
STEP 11 — EMPTY STATES / LOADING

Replace:

dark greys → light greys
icons → #BDBDBD
STEP 12 — REMOVE INCONSISTENCIES

Search and replace:

Colors.grey → use theme.outline / neutral palette
Colors.red → use theme.colorScheme.error
Colors.green → define semantic success color
STEP 13 — DESIGN SYSTEM RULES

Enforce:

Max 3 colors on any screen
White is dominant (70–80%)
Beige used for separation, not base
Red only for:
CTA
Active state
Important alerts
STEP 14 — FINAL PASS

Ensure:

No dark UI remains
No purple anywhere
No hardcoded colors unless from system
All components use Theme.of(context)
OUTPUT FORMAT
Updated theme file
Updated AppBrandStyles
Refactored AppScaffold
Sample updated:
Home card
Chat UI
Button styles

Do NOT break functionality.
Do NOT change routing or business logic.
Focus only on UI consistency and visual system.