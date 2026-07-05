# Calendar App — Project Document

## Overview
A social calendar app for Apple devices that aggregates calendars from iCloud, Google, and Outlook into a single view, letting users see friends' availability in one place.

## Decisions & Recommendations

| Topic | Decision |
|---|---|
| Platform | Universal — iOS, iPadOS, macOS |
| Min iOS | **iOS 17** (recommended — best SwiftUI maturity, latest EventKit) |
| Calendar providers | iCloud (EventKit), Google Calendar API, Microsoft Graph (Outlook) |
| Sync direction | Read-only |
| Friend discovery | Phone number lookup |
| Sharing granularity | Per-event (user opts each event in/out) |
| Groups | Start with "Close Friends" |
| Backend | **Supabase** (recommended — free tier, built-in SMS/OTP auth, real-time, great Swift SDK) |
| Availability storage | Supabase (social graph + per-event share settings); calendar data stays on-device via EventKit |
| UI style | Apple-native (SwiftUI, system components) |
| Calendar view | Standard day / week / month |

## Architecture

```
Device
 └── EventKit              ← iCloud / local calendar
 └── Google Calendar API   ← OAuth 2.0 (Google Cloud Console app required)
 └── Microsoft Graph API   ← OAuth 2.0 (Azure app registration required)
          ↓
   CalendarService (unified model)
          ↓
   SwiftUI Views

Supabase Backend
 └── Users (phone-based auth)
 └── Friendships
 └── Groups (Close Friends, etc.)
 └── EventShareSettings (per-event opt-in)
 └── AvailabilityQuery (friend free/busy lookup)
```

## Tech Stack
- **SwiftUI** + Swift 5.9+
- **EventKit** for Apple Calendar
- **GoogleSignIn** + Google Calendar REST API
- **MSAL (Microsoft Authentication Library)** + Microsoft Graph API
- **Supabase Swift SDK** for backend

## Third-Party Setup Required
Before running:
1. **Google**: Create OAuth 2.0 credentials in Google Cloud Console → enable Google Calendar API
2. **Microsoft**: Register an app in Azure Active Directory → add Microsoft Graph Calendar.Read scope
3. **Supabase**: Create a free project → enable Phone auth (Twilio or built-in OTP)

## Project Structure
```
CalendarApp/
├── App/
│   └── CalendarAppApp.swift
├── Config/
│   └── Secrets.swift          ← API keys (gitignored)
├── Models/
│   ├── CalendarEvent.swift
│   ├── User.swift
│   ├── Friend.swift
│   └── Group.swift
├── Services/
│   ├── UnifiedCalendarService.swift
│   ├── AppleCalendarService.swift
│   ├── GoogleCalendarService.swift
│   ├── OutlookCalendarService.swift
│   └── SupabaseService.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── CalendarViewModel.swift
│   └── FriendsViewModel.swift
└── Views/
    ├── Auth/
    │   ├── PhoneAuthView.swift
    │   └── OTPVerificationView.swift
    ├── Calendar/
    │   ├── CalendarContainerView.swift
    │   ├── MonthView.swift
    │   ├── WeekView.swift
    │   └── DayView.swift
    ├── Events/
    │   ├── EventDetailView.swift
    │   └── EventSharingSheet.swift
    ├── Social/
    │   ├── FriendsView.swift
    │   ├── AddFriendView.swift
    │   └── FriendAvailabilityView.swift
    └── Settings/
        ├── SettingsView.swift
        └── ConnectedCalendarsView.swift
```

## Status
- [x] Requirements gathering
- [ ] Build prototype
- [ ] Third-party credential setup
- [ ] Testing on device
