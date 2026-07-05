# CalendarSync -- Project Overview

**A social calendar platform that unifies iCloud, Google, and Outlook calendars into one view and lets users see friends' availability, share events, and plan together.**

CalendarSync ships as two clients backed by a single Supabase project:

| Client | Location | Stack | Target |
|---|---|---|---|
| **iOS / iPadOS / macOS app** | `apps/ios/` | SwiftUI, Swift 5.9+, Xcode 15+ | Apple devices (iOS 17+) |
| **Web / cross-platform app** | `apps/web/` | React Native (Expo 54), TypeScript, Expo Router | Web browsers, Android (via Expo) |

> A third client — a native Android app (Kotlin / Jetpack Compose) — is archived in `docs/archive/android-native/`. The Expo app covers Android; see `docs/archive/android-native/ARCHIVED.md` for why.

All clients share the same Supabase backend, Postgres schema, and RLS policies. A user can sign in on any platform and interact with the same social graph.

---

## Architecture

```
                         +--------------------------+
                         |     Supabase Backend     |
                         |  (Postgres + Auth + RLS) |
                         +--------+--------+--------+
                                  |        |
                   +--------------+        +--------------+
                   |                                      |
        +----------+----------+              +------------+-----------+
        |   iOS App (Swift)   |              |   Web App (Expo/RN)    |
        |                     |              |                        |
        |  EventKit (Apple)   |              |  Google Calendar API   |
        |  Google Calendar API|              |  Supabase Auth (OAuth) |
        |  Microsoft Graph API|              |  Expo Router           |
        |  Supabase Swift SDK |              |  Supabase JS SDK       |
        +---------------------+              +------------------------+
```

### Backend (shared)

- **Supabase Auth** -- Email OTP (magic link), Sign in with Apple, Sign in with Google. No passwords.
- **Postgres** with Row-Level Security on every table. Users can only read/write data they own or are permitted to see via group membership.
- **RPC functions** -- `get_availability` enforces group-based visibility server-side, returning only the slots a viewer is allowed to see and redacting event titles when the owner hasn't opted to share details.
- **Database tables**: `profiles`, `friendships`, `groups`, `group_members`, `event_shares`, `availability_slots`, `shared_events`, `event_invites`, `device_tokens`.
- **Migrations** are versioned SQL files in `supabase/migrations/` and can be applied via the Supabase CLI (`supabase db push`) or the SQL Editor.

### iOS App

- Built with **SwiftUI** and managed via **XcodeGen** (`project.yml`).
- **EventKit** for native Apple Calendar read/write access.
- **Google Sign-In SDK** + Google Calendar REST API for Google Calendar sync.
- **MSAL (Microsoft Authentication Library)** + Microsoft Graph API for Outlook Calendar sync.
- **UnifiedCalendarService** aggregates all three providers into a single sorted event stream.
- **APNs push notifications** with deep-link routing for friend requests and event invites.
- Calendar views: Month, Week, Day -- all built as native SwiftUI views with smooth transitions.

### Web App

- **Expo 54** with **Expo Router** (file-based routing).
- **Supabase JS SDK** for auth and data, with **expo-secure-store** for token persistence on native and `localStorage` on web.
- **Google Calendar REST API** -- after OAuth via Supabase, the Google provider token is captured and used to fetch events directly.
- Tab-based navigation: Calendar, Friends, Settings.

---

## Features

### Multi-Provider Calendar Aggregation

Both clients pull events from multiple calendar providers and merge them into a unified timeline:

| Provider | iOS | Web |
|---|---|---|
| Apple Calendar (EventKit) | Full read + write | N/A (Apple platform only) |
| Google Calendar | Read via REST API | Read via REST API |
| Microsoft Outlook | Read via Graph API | Planned |

Events are prefixed by source (`apple-`, `google-`, `outlook-`) to avoid ID collisions. The iOS app fetches all providers concurrently using Swift concurrency (`async let`, `TaskGroup`). The web app fetches Google Calendar events using the OAuth provider token from the Supabase session.

### Authentication

- **Email OTP** -- passwordless sign-in via a 6-digit code sent to the user's email (both platforms).
- **Sign in with Apple** -- native `ASAuthorizationAppleIDRequest` flow on iOS, forwarded to Supabase via ID token.
- **Sign in with Google** -- Google Sign-In SDK on iOS; Supabase OAuth redirect on web.
- Sessions are persisted locally (Keychain on iOS, SecureStore/localStorage on web) and auto-refreshed.

### Social Graph

- **Friend requests** -- send by email, accept/decline. Friendships are bidirectional; the schema enforces a unique `(requester_id, addressee_id)` pair.
- **Groups** -- user-created groups (e.g. "Close Friends", "Work"). A default "Close Friends" group is auto-created on first load.
- **Group membership** -- friends can be added to/removed from groups. Group membership controls what calendar data is visible.

### Availability Sharing

The core social feature. Users opt individual events into sharing with specific groups:

1. **Event sharing** -- per-event, per-group opt-in. Each share record controls whether details (title) are visible or only busy/free status.
2. **Availability query** -- the `get_availability` Postgres function joins `availability_slots` with `event_shares` and `group_members` to return only the slots a viewer is permitted to see. Titles are redacted unless `is_details_visible` is true.
3. **Calendar overlay** -- on iOS, friends' busy slots can be overlaid on the user's own Week and Day views with per-friend color coding. Overlay preferences persist in `UserDefaults`.

### Shared Events and Invites

A lightweight event-planning flow that lives alongside calendar sync:

1. **Create a shared event** -- title, date/time, location, notes. Select friends to invite.
2. **Send invites** -- each invitee receives an in-app notification (and eventually email via an Edge Function). Invites are stored in `event_invites` with `pending`/`accepted`/`declined` status.
3. **Respond to invites** -- accept or decline from the Friends tab. On iOS, accepted events can be written to a local calendar via EventKit.
4. **Badge counts** -- both platforms show unread invite/request counts as tab badges.

### Push Notifications (iOS)

- APNs registration and token storage in Supabase (`device_tokens` table).
- Deep-link routing: tapping a "friend request" notification opens the Friends tab; tapping an "event invite" notification opens the invite detail.
- Foreground banner display via `UNUserNotificationCenterDelegate`.
- Debug mode includes test notification scheduling for development.
- **Server-side delivery**: A Supabase Edge Function (`push-notification`) sends APNs pushes when database triggers fire on new `friendships` or `event_invites` rows.

### Contact Import (Instagram / WhatsApp)

A friend discovery flow available from the Friends screen (both iOS and web):

1. **Source selection** -- choose Instagram or WhatsApp (device contacts).
2. **Contact scanning** -- on iOS, reads device contacts via `CNContactStore` (contacts synced from WhatsApp or iCloud). On web, users paste email addresses manually (Instagram/WhatsApp APIs require app review for automated access).
3. **Cross-reference** -- emails are batch-looked up against the `profiles` table to find existing CalendarSync users.
4. **Bulk friend requests** -- matched contacts are shown with checkboxes. Users can select all or specific contacts and send friend requests in one tap.

### Android App (archived)

Android is served by the Expo app (`npm run android` in `apps/web/`). An earlier native Kotlin/Jetpack Compose client lives in `docs/archive/android-native/` and had:

- **Jetpack Compose UI** with Material 3, dark mode support, and bottom navigation (Calendar, Friends, Settings tabs).
- **Supabase Kotlin SDK** for auth (email OTP, Google ID token sign-in) and data.
- **Google Calendar REST API** via Ktor HTTP client.
- **Android CalendarProvider** for reading device calendar events.
- **Hilt** for dependency injection.
- Navigation via `navigation-compose`.

---

## Third-Party API Integration

### Google Calendar API

**Setup:**
1. Google Cloud Console -- create a project, enable the Google Calendar API and Google Sign-In.
2. Create an OAuth 2.0 Client ID (iOS type for the native app; web type for Supabase OAuth).
3. Add the reversed client ID to `CFBundleURLSchemes` in the iOS project for redirect handling.
4. Enable Google as an OAuth provider in Supabase Auth settings.

**Integration:**
- iOS: `GoogleSignIn` SDK handles the OAuth flow and token refresh. `GoogleCalendarService` calls the Calendar v3 REST API with the access token.
- Web: Supabase `signInWithOAuth({ provider: 'google' })` handles the redirect. The `provider_token` on the session is the Google access token, passed to `fetchGoogleCalendarEvents()`.

### Microsoft Graph API (Outlook)

**Setup:**
1. Azure Portal -- register an app in Azure Active Directory.
2. Add iOS platform with the app's bundle ID.
3. Grant delegated permissions: `Calendars.Read`, `User.Read`.
4. Copy the Application (client) ID into `Secrets.swift`.

**Integration:**
- MSAL handles interactive and silent token acquisition.
- `OutlookCalendarService` calls the Graph `/me/calendarView` endpoint.
- Gracefully degrades if Azure credentials aren't configured (`isConfigured` check).

### Apple Calendar (EventKit)

- No external API setup required. Uses the system EventKit framework.
- Requests `fullAccess` permission on iOS 17+.
- Read access for calendar display; write access for adding accepted shared events to a local calendar.

### Supabase

**Setup:**
1. Create a Supabase project (free tier).
2. Run the migration files in order via the SQL Editor or CLI.
3. Enable Email OTP in Authentication settings (no Twilio required).
4. Enable Apple and Google as OAuth providers (optional, for social sign-in).
5. For push notifications: store APNs credentials as Supabase secrets.

---

## Database Schema

| Table | Purpose | RLS |
|---|---|---|
| `profiles` | User identity (id, email, display name, avatar) | Own profile: full access. All profiles: read (for friend search). |
| `friendships` | Bidirectional friend connections with status | Participants can read; requester can create; addressee can update status. |
| `groups` | User-created friend groups | Owner has full access. |
| `group_members` | Many-to-many group membership | Group owner has full access. |
| `event_shares` | Per-event, per-group sharing opt-in | Owner manages; group members can read. |
| `availability_slots` | Denormalized busy-slot cache | Owner manages; friends in shared groups can read. |
| `shared_events` | User-created events for planning with friends | Organizer has full access. |
| `event_invites` | Invitations to shared events | Invitee has full access; organizer can read. |
| `device_tokens` | APNs push notification tokens | Owner manages. |

---

## Project Structure

```
CalendarSync/
  README.md                         # This file
  supabase/                         # Shared backend — single source of truth
    migrations/                     # Versioned Postgres migrations
    functions/push-notification/    # Edge Function for APNs delivery

  apps/
    ios/                            # iOS/iPadOS/macOS native app
      CalendarApp/
        App/                        # App entry point, AppDelegate
        Config/                     # Secrets.swift (gitignored; copy from Secrets.swift.example)
        Models/                     # Data models (CalendarEvent, AppUser, Friend, etc.)
        Resources/                  # Info.plist, entitlements, privacy manifest
        Services/                   # Calendar providers, Supabase client, notifications
        Utilities/                  # Haptic feedback helpers
        ViewModels/                 # Auth, Calendar, Friends view models
        Views/
          Auth/                     # Phone/email sign-in, OTP verification
          Calendar/                 # Month, Week, Day views, container
          Events/                   # Event detail, sharing sheet, create event, invite view
          Settings/                 # Settings, connected calendars
          Social/                   # Friends list, add friend, availability, import contacts
      CalendarApp.xcodeproj/        # Xcode project (generated via XcodeGen)
      project.yml                   # XcodeGen spec

    web/                            # Expo/React Native web + mobile app (also the Android client)
      app/
        _layout.tsx                 # Root layout with auth guard
        (auth)/                     # Sign-in, OTP verification screens
        (tabs)/                     # Calendar, Friends, Settings tabs
      src/
        components/                 # CreateEventModal, FriendAvailability, ImportContactsModal
        contexts/                   # AuthContext, FriendsContext (React context providers)
        services/                   # Supabase client, Google Calendar API
        types/                      # TypeScript interfaces

  docs/
    PROJECT.md                      # Original iOS project document
    MISTAKES.md                     # Lessons learned
    assets/                         # Logo and brand assets
    archive/android-native/         # Archived native Kotlin/Compose Android app
```

---

## Publishing

### iOS App Store

1. **Apple Developer Program** -- enroll at developer.apple.com ($99/year).
2. **Certificates and Profiles** -- generate a distribution certificate and provisioning profile in Xcode (Automatic signing handles this).
3. **App Store Connect** -- create the app listing with screenshots, description, and metadata.
4. **Privacy** -- the app includes a `PrivacyInfo.xcprivacy` manifest declaring calendar, contacts, and network access.
5. **Archive and Upload** -- `Product > Archive` in Xcode, then upload to App Store Connect via the Organizer.
6. **Review** -- Apple reviews the app. Ensure the privacy descriptions in `Info.plist` are user-facing and accurate.

### Google Play Store (Android)

Android ships from the Expo app (`apps/web/`):

1. **Google Play Console** -- enroll at play.google.com/console ($25 one-time).
2. **Build** -- use EAS Build (`npx eas build --platform android`) to produce a signed AAB, or `npx expo prebuild` + Gradle for a local build.
3. **Store Listing** -- create the app listing with screenshots, description, and privacy policy.
4. **Review** -- Google reviews the app. Ensure calendar and contacts permissions are justified.

### Web Deployment

1. **Build** -- `npx expo export --platform web` generates a static site in `dist/`.
2. **Host** -- deploy to Netlify, Vercel, or any static host. The Supabase OAuth redirect URI must match the deployment domain.
3. **Environment** -- the Supabase URL and anon key are embedded in the client. For production, move these to environment variables at build time.

### Supabase Production

1. **Upgrade** from free tier if needed (for higher request limits and custom domains).
2. **Enable RLS on all tables** (already configured in migrations).
3. **Set up Edge Functions** for server-side email sending (invites) and push notification dispatch.
4. **Configure secrets** -- APNs credentials, SMTP for email, any webhook URLs.
5. **Enable backups** and point-in-time recovery on the Supabase dashboard.

---

## Development

### Prerequisites

- Xcode 15+ (iOS app)
- Node.js 18+ (web app)
- Supabase CLI (optional, for local development and migrations)
- Google Cloud Console project with Calendar API enabled
- Azure AD app registration (optional, for Outlook)

### Running the iOS App

```bash
cd apps/ios
# First time: create your secrets file
cp CalendarApp/Config/Secrets.swift.example CalendarApp/Config/Secrets.swift  # then fill in values
# Generate Xcode project from spec (if using XcodeGen)
xcodegen generate
# Open in Xcode
open CalendarApp.xcodeproj
# Build and run on simulator or device
```

### Running the Web App

```bash
cd apps/web
npm install
npm run web        # Opens in browser
npm run ios        # Opens iOS simulator (requires Xcode)
npm run android    # Opens Android emulator
```

### Applying Database Migrations

```bash
# Via Supabase CLI
supabase db push

# Or manually in Supabase SQL Editor:
# Run each file in supabase/migrations/ in numeric order
```
