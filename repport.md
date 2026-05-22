# Audio App Report

Date: 2026-05-22

## Overview
This Flutter app is a Spotify-like audio experience that focuses on authentication, biometric gating, an audio player with background playback, and user stats. It integrates Firebase for authentication and favorites storage, uses local storage for listening statistics, and pulls audio previews from an external catalog API.

## Project Structure
Top-level layout (non-exhaustive):

```
android/
ios/
linux/
macos/
web/
windows/
assets/
  icons/
  images/
lib/
  main.dart
  models/
  screens/
  services/
  utils/
pubspec.yaml
analysis_options.yaml
README.md
```

Lib tree (app code):

```
lib/
  main.dart
  models/
    audio_track.dart
  screens/
    auth/
      auth_page.dart
    home/
      home_page.dart
      stats_tab.dart
      player_tab.dart
      favorites_tab.dart
  services/
    auth_service.dart
    biometric_service.dart
    audio_catalog_service.dart
    audio_player_service.dart
    favorites_service.dart
    local_stats_service.dart
  utils/
    dialog_helper.dart
```

## Core App Flow
1. App startup initializes Flutter bindings, requests Android notification permission, initializes AudioService, and then initializes Firebase.
2. StartupGate enforces biometric authentication before the user can access the auth flow.
3. AuthGate listens to Firebase auth state:
   - Signed out: AuthPage (login/register/reset).
   - Signed in: HomePage with bottom navigation tabs.

Home tabs:
- Stats: Profile greeting, total listening time, monthly goal, daily minutes chart, top tracks.
- Player: Search and browse catalog, play previews, background playback, favorites toggle.
- Favorites: Firestore-backed list with biometric-protected deletion.

## Services and Responsibilities
- AuthService: Firebase Auth (login/register/logout/reset) and user profile storage in Firestore.
- BiometricService: Local Auth for fingerprint checks, first-launch gating, and Android security settings intent.
- AudioCatalogService: External catalog fetch via HTTP; currently uses iTunes Search API.
- AudioPlayerService: Playback control using audio_service + just_audio; exposes player and playback state streams.
- FavoritesService: Firestore CRUD for user favorites under users/{uid}/favorites.
- LocalStatsService: SharedPreferences storage for total minutes, daily minutes, top tracks, and monthly goal.
- DialogHelper: Standardized error/success/info/confirm dialogs.

Note: README references mp3quran as the external source, but the current code uses the iTunes Search API in AudioCatalogService.

## Data and Storage
- Firebase Auth: User authentication (email/password).
- Firestore:
  - users/{uid}: profile data (firstName, lastName, birthDate).
  - users/{uid}/favorites: favorite tracks.
- Local storage (SharedPreferences):
  - total minutes listened
  - daily minutes (by date)
  - top tracks (by title)
  - monthly goal hours

## Audio and Background Playback
- AudioPlayerHandler (in main.dart) wraps just_audio with audio_service.
- AudioServiceConfig enables Android notification controls for playback.
- Player tab controls play/pause, seek, repeat, and shows a now-playing sheet.

## Design System and UI
- Visual style: dark theme with glassmorphism cards and blur effects.
- Fonts: Google Fonts Sora for the app typography.
- App background: global linear gradient applied in MaterialApp builder.
- Auth screen: background image with dark overlay gradient + glass panel.
- Reusable card styling: semi-transparent white, rounded corners, thin border.

### Color Palette (from theme and UI)
Primary/accent:
- #7FD8FF (primary, secondary, accent icons, buttons)

Surfaces and backgrounds:
- #0B0F14 (gradient)
- #101826 (gradient)
- #0C141A (gradient)
- #121922 (surface)
- #33121922 (app bar / bottom nav translucent)
- #CC10161D (dialog background)
- #CC0F141A (snackbar background)

Text:
- #EAF2F8 (onSurface)

Glass cards:
- White at 0.08 opacity (fill)
- White at 0.12 opacity (border)

## Assets
- assets/images/login-bg.jpg (auth background)
- assets/icons/app-icon.svg (logo in auth and app bar)

## Dependencies (key packages)
- firebase_core, firebase_auth, cloud_firestore
- shared_preferences
- local_auth, android_intent_plus
- http
- just_audio, audio_service, just_audio_background
- permission_handler
- google_fonts, flutter_svg
- intl

## Platforms
The project includes standard Flutter platform folders: Android, iOS, web, Windows, macOS, and Linux. Android is explicitly configured for Firebase and audio notifications.
