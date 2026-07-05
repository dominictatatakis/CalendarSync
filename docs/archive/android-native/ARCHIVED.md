# Archived: native Android app (Kotlin / Jetpack Compose)

This native Android client was archived on 2026-07-05 when the CalendarSync
projects were consolidated into this monorepo.

**Why:** the Expo app in `apps/web/` already targets Android (`npm run android`),
and this native client was the least complete of the three (month grid, friends
list, and settings only — no Outlook sync, no push notifications). Maintaining
two Android clients wasn't worth it.

It is kept here for reference in case a native Kotlin client is revived later.
Note the `gradle/` wrapper directory was empty when archived, so a wrapper
(`gradle wrapper`) would need to be regenerated to build it.
