# biPi - Audio App

A Flutter mobile application built for a university project featuring audio playback with biometric authentication, favorites management, and listening statistics.

---

## 1. App Identity

### App Name
- **Current Name**: `audio_app`
- **Display Name**: `biPi`

### Colors (Theme)
The app uses a dark theme with the following primary colors (sourced from [lib/main.dart](lib/main.dart#L150-L152)):

| Color | Hex Code | Usage |
|-------|----------|-------|
| Primary | `#7FD8FF` | Accent, buttons, selected items |
| Secondary | `#7FD8FF` | Same as primary |
| Surface | `#121922` | Card backgrounds |
| On Surface | `#EAAF2F8` | Text color |
| Background Dark 1 | `#0B0F14` | Gradient top-left |
| Background Dark 2 | `#101826` | Gradient center |
| Background Dark 3 | `#0C141A` | Gradient bottom-right |

The app applies a gradient background across all screens using these dark blues and adds glass-morphism effects with semi-transparent whites.

### Typography/Fonts
- **Font Family**: `Sora` (via Google Fonts package `google_fonts: ^6.3.3`)
- **Theme**: Google Fonts Sora Text Theme applied to Material Dark theme
- **Source**: [lib/main.dart](lib/main.dart#L164)

---

## 2. Technical Architecture

### Flutter Packages Used

#### Audio & Media
- `just_audio: ^0.9.46` - Audio player library
- `just_audio_background: ^0.0.1-beta.17` - Background audio playback support
- `audio_service: ^0.18.18` - Audio service for system integration

#### Firebase & Backend
- `firebase_core: ^3.13.1` - Firebase initialization
- `firebase_auth: ^5.5.1` - Authentication
- `cloud_firestore: ^5.6.5` - Database

#### Security & Device Access
- `local_auth: ^2.3.0` - Biometric authentication
- `android_intent_plus: ^5.3.0` - Android settings integration
- `permission_handler: ^11.3.1` - Runtime permissions

#### Storage & Preferences
- `shared_preferences: ^2.5.3` - Local key-value storage

#### Networking & Utilities
- `http: ^1.3.0` - HTTP requests
- `intl: ^0.20.2` - Internationalization
- `google_fonts: ^6.3.3` - Google Fonts integration
- `flutter_svg: ^2.0.10` - SVG rendering

**Source**: [pubspec.yaml](pubspec.yaml#L8-L24)

### External API

#### iTunes Search API
The app uses Apple's iTunes Search API to fetch audio content (Quran recitations and other audio).

**Base URL**: `https://itunes.apple.com/search`

**Endpoints Used**:
```
GET /search?term={query}&entity=song&limit=50
```

**Parameters**:
- `term`: Search query (default: "quran recitation")
- `entity`: "song" (audio content type)
- `limit`: 50 results

**Source**: [lib/services/audio_catalog_service.dart](lib/services/audio_catalog_service.dart#L9-L11)

**Response Mapping**:
- `previewUrl` → Audio URL
- `trackId` → Track ID
- `trackName` → Title
- `artistName` → Category/Artist
- `artworkUrl100` → Artwork (converted to 600x600)

### Data Storage

#### Stored in Firebase Firestore
- **`users` collection**
  - Document ID: User UID (Firebase Auth)
  - Fields: `firstName`, `lastName`, `birthDate` (Timestamp), `createdAt`
  - Source: [lib/services/auth_service.dart](lib/services/auth_service.dart#L27-L37)

- **`{uid}/favorites` subcollection**
  - Document ID: Track ID
  - Fields: `id`, `title`, `category`, `url`, `artwork`
  - Source: [lib/services/favorites_service.dart](lib/services/favorites_service.dart#L7-8)

#### Stored Locally (SharedPreferences)
- `stats_total_minutes` → Total listening time in minutes
- `stats_daily_minutes` → JSON map of daily listening per date
- `stats_top_tracks` → JSON map of top tracks by title
- `monthly_goal_hours` → Monthly listening goal (default: **20 hours**)
- `biometric_first_launch_done` → Flag for first launch biometric validation

**Source**: [lib/services/local_stats_service.dart](lib/services/local_stats_service.dart#L5-8)

---

## 3. Security Features

### Biometric Authentication

#### Implementation Package
- **Package**: `local_auth: ^2.3.0`
- **Class**: `BiometricService` → [lib/services/biometric_service.dart](lib/services/biometric_service.dart)
- **Method**: `authenticate(reason: String)` (lines 77-115)

#### Where Biometric Auth is Triggered

1. **App Startup (MANDATORY)** 
   - Triggered in: `StartupGate` widget → [lib/main.dart](lib/main.dart#L273)
   - Flow: App launch → Biometric check → Authentication prompt
   - Re-triggered when app resumes from background (paused state)
   - Source: [lib/main.dart#L283-L290](lib/main.dart#L283-L290)

2. **Deleting Favorites**
   - Triggered in: `FavoritesTab._deleteFavorite()` → [lib/screens/home/favorites_tab.dart](lib/screens/home/favorites_tab.dart#L19-24)
   - Method: `_biometricService.authenticate(reason: 'Authentifiez-vous pour supprimer ce favori.')`

#### No Fingerprint Enrolled
**What Happens** ([lib/main.dart](lib/main.dart#L308-318)):
- Device support is checked: `hasBiometricConfigured()` → `isDeviceSupported()` and `getAvailableBiometrics()`
- If no biometric configured: User sees error dialog with text: *"Empreinte introuvable. Configurez votre empreinte digitale pour continuer."* (Fingerprint not found. Configure your fingerprint to continue.)
- User can tap **"Passer"** (Skip) button to bypass and continue to login
- Opens Android Security Settings on demand via `AndroidIntent`

#### Biometric Success Sound
- **Sound Type**: `SystemSoundType.click` (system click/tap sound)
- **Source**: [lib/services/biometric_service.dart](lib/services/biometric_service.dart#L100-104)
- The sound plays inside a try-catch; errors are silently ignored

### Firebase Authentication

#### Flows Implemented

**1. Login** ([lib/services/auth_service.dart](lib/services/auth_service.dart#L14-16))
```dart
Future<void> login({required String email, required String password})
  → FirebaseAuth.signInWithEmailAndPassword(email, password)
```

**2. Registration** ([lib/services/auth_service.dart](lib/services/auth_service.dart#L18-37))
```dart
Future<void> register({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required DateTime birthDate,
})
  → Creates Firebase Auth user
  → Stores user profile in Firestore
```

**3. Password Reset** ([lib/services/auth_service.dart](lib/services/auth_service.dart#L39-41))
```dart
Future<void> resetPassword(String email)
  → FirebaseAuth.sendPasswordResetEmail(email)
```

#### Registration Validation Rules

**Required Fields** ([lib/screens/auth/auth_page.dart](lib/screens/auth/auth_page.dart#L79-95)):
- Email (validated via Firebase)
- Password (validated via Firebase)
- First Name (trimmed, not empty)
- Last Name (trimmed, not empty)
- Birth Date (mandatory)

**Age Check**:
- **Minimum Age**: **13 years old**
- Enforced on registration before user creation
- Age calculated from birth date: `_calculateAge(birthDate)` method
- Source: [lib/screens/auth/auth_page.dart](lib/screens/auth/auth_page.dart#L58-83)

---

## 4. Features

### Home/Stats Page Display

**Welcome Message**: "Bienvenue, {First Name} {Last Name}"

**Components** ([lib/screens/home/stats_tab.dart](lib/screens/home/stats_tab.dart)):

1. **Total Listening Time**
   - Display: `{hours}h {minutes}m` (converted from stored minutes)
   - Source: Local stats service

2. **Monthly Goal**
   - Dropdown selector: 5h, 10h, 15h, 20h, ... 50h
   - **Default**: **20 hours**
   - Progress bar showing current vs goal
   - Formula: `progress = (totalMinutes / goalMinutes).clamp(0, 1)`

3. **Top Tracks List**
   - Sorted by listening count (descending)
   - Shows track titles and play counts

4. **User Profile**
   - Fetched from Firestore `users` collection
   - Displays: First Name, Last Name

### Monthly Goal Storage

- **Storage Location**: Local (SharedPreferences)
- **Key**: `monthly_goal_hours`
- **Default Value**: **20 hours**
- **Type**: Integer (hours)
- **Setter**: `LocalStatsService.setGoalHours(hours)`
- **Getter**: `LocalStatsService.getGoalHours()`
- **Source**: [lib/services/local_stats_service.dart](lib/services/local_stats_service.dart#L14-20)

### Audio Player Structure

#### Categories
- Fetched from iTunes API via search
- **Default Search**: "quran recitation"
- Artist names become category names
- User can search for custom categories

#### Tracks
- Grouped by category (artist)
- Fields: `id`, `title`, `category`, `url` (preview), `artwork`
- Artwork automatically upscaled from 100x100 to 600x600

#### Player Controls
- **Play/Pause**
- **Seek forward** (skip ahead)
- **Seek backward** (rewind)
- **Stop**
- **Current position** and buffered position tracking
- **Playback speed** support

**Source**: [lib/services/audio_player_service.dart](lib/services/audio_player_service.dart)  
**UI**: [lib/screens/home/player_tab.dart](lib/screens/home/player_tab.dart)

### Background Audio Playback

**Supported**: ✅ Yes

**Implementation**:
- **Package**: `audio_service: ^0.18.18` (with `just_audio_background`)
- **Handler**: `AudioPlayerHandler` extends `BaseAudioHandler` with `SeekHandler`
- **Android Config**:
  - Notification Channel: `com.example.audio_app.channel.audio`
  - Channel Name: `Audio playback`
  - Ongoing Notification: Enabled
- **Features**: Playback controls from lock screen/notification, state persistence
- **Initialization**: [lib/main.dart](lib/main.dart#L130-139)

### Favorites Management

#### Add Favorite
- Triggered when user taps favorite button on player
- **Biometric Required**: ❌ No (only for deletion)
- Stores track to Firestore subcollection `users/{uid}/favorites/{trackId}`
- Source: [lib/services/favorites_service.dart](lib/services/favorites_service.dart#L20-22)

#### Delete Favorite
- **Biometric Required**: ✅ Yes
- Reason: `"Authentifiez-vous pour supprimer ce favori."`
- Removes document from Firestore subcollection
- Source: [lib/screens/home/favorites_tab.dart](lib/screens/home/favorites_tab.dart#L19-24)

#### Sync
- Real-time sync via Firestore Snapshots (StreamBuilder)
- Any changes in Firestore immediately reflect in UI
- Favorites fetched as stream: `FavoritesService.streamFavorites(uid)`
- Source: [lib/services/favorites_service.dart](lib/services/favorites_service.dart#L11-18)

---

## 5. Firebase Integration

### Firestore Collections & Document Structure

#### `users` Collection
```
users/
  {uid}/
    firstName: String
    lastName: String
    birthDate: Timestamp
    createdAt: Timestamp (server time)
```
- **Document ID**: Firebase Auth UID
- **Purpose**: Store user profile information
- **Creation**: Triggered on registration
- **Source**: [lib/services/auth_service.dart](lib/services/auth_service.dart#L27-37)

#### `users/{uid}/favorites` Subcollection
```
users/{uid}/favorites/
  {trackId}/
    id: String
    title: String
    category: String
    url: String
    artwork: String (nullable)
```
- **Document ID**: Track ID (iTunes track ID)
- **Purpose**: Store user's favorite audio tracks
- **Operations**: Add, delete, stream (real-time)
- **Source**: [lib/services/favorites_service.dart](lib/services/favorites_service.dart)

### Firebase vs Local Storage

| Data | Storage | Reason |
|------|---------|--------|
| User Profile (name, birthDate) | Firebase Firestore | Shared across devices, secure |
| Favorites | Firebase Firestore | Sync across devices, persistent |
| Total Listening Minutes | Local (SharedPreferences) | Performance, real-time tracking |
| Daily Listening Stats | Local (SharedPreferences) | Frequent writes, local-only tracking |
| Top Tracks | Local (SharedPreferences) | Local analytics, real-time updates |
| Monthly Goal | Local (SharedPreferences) | User preference, device-specific |
| Biometric First Launch Flag | Local (SharedPreferences) | Device enrollment status |

---

## Important Notes

⚠️ **Do NOT Change** (tied to Firebase):
- `android/app/build.gradle.kts` → `applicationId: "com.example.audio_app"`
- `android/app/google-services.json` → Firebase configuration
- Firestore collection names (`users`, `favorites`)

---

## Project Structure

```
lib/
├── main.dart                    # App initialization, startup gate, biometric flow
├── models/
│   └── audio_track.dart        # AudioTrack model
├── screens/
│   ├── auth/
│   │   └── auth_page.dart      # Login/Register UI
│   └── home/
│       ├── home_page.dart      # Main app with bottom nav
│       ├── stats_tab.dart      # Stats and listening goals
│       ├── player_tab.dart     # Audio player UI
│       └── favorites_tab.dart  # Favorites management
├── services/
│   ├── auth_service.dart       # Firebase Auth operations
│   ├── audio_catalog_service.dart  # iTunes API integration
│   ├── audio_player_service.dart   # Player control abstraction
│   ├── biometric_service.dart  # Biometric auth
│   ├── favorites_service.dart  # Firestore favorites
│   └── local_stats_service.dart    # Local statistics
└── utils/
    └── dialog_helper.dart      # Reusable dialogs
```

---

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK (Android)
flutter build apk

# Build iOS
flutter build ios
```

---


