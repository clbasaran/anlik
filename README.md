# anlık.

> **A solo-built, production-shipped iOS social photo app.**
> Swift 6 · Strict Concurrency · SwiftUI · Firebase · WidgetKit · Live Activities

[![App Store](https://img.shields.io/badge/App%20Store-Live-000000?logo=apple)](https://apps.apple.com/tr/app/anl%C4%B1k/id6450062813)
[![iOS](https://img.shields.io/badge/iOS-17%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![Swift Concurrency](https://img.shields.io/badge/Concurrency-Strict-purple)](https://developer.apple.com/documentation/swift/concurrency)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

**anlık.** is a real-time, filter-free social photo app for close friends. Users share unedited "moments" with a small circle, build daily streaks, comment on each other's photos, and add live drawings or text. Position: between Snapchat (private, ephemeral) and BeReal (authentic, in-the-moment) — but built for Turkey-first audiences.

I shipped this app solo as a learning vehicle: ~14,900 lines of Swift covering camera capture, real-time messaging, push notifications, widgets, Live Activities, Watch app, and a Cloud Functions backend.

---

## 📸 Screenshots

> Screenshots coming soon — clone & build to see it live, or grab the app from the App Store.

| Camera | Friends | History | Memories |
| :---: | :---: | :---: | :---: |
| _capture_ | _list_ | _grid_ | _recap_ |

---

## 🎯 What's Interesting Here

This isn't a tutorial app. It's a production codebase that ships to real users, with all the messy edges that come with that:

- **Swift 6 strict concurrency** across the entire codebase — every service is an `actor`, all view models are `@Observable`, zero data-race warnings.
- **Repository + Dependency Injection** pattern with protocol-based services, swappable for testing.
- **Offline-first architecture** combining Firestore persistent cache + SwiftData + a JSON file fallback.
- **Custom AVFoundation camera** with parallel capture + location sampling, safety timeouts, HEVC video recording, and a long-press shutter for video.
- **Live Activities + Dynamic Island** for upload progress, fully styled.
- **Three widget sizes + Lock Screen widget** with 3-layered data loading (App Group → cached image → remote).
- **Cloud Functions backend** (12 functions) handling streak calculation, push notifications, content moderation (Cloud Vision SafeSearch), and weekly summary cron jobs.
- **Server-side streak calculation** — clients can't fake it. Five tiers, friendship score, leaderboard.
- **GDPR/KVKK-compliant** cascade delete (9 client steps + 9 server steps).
- **Apple Sign-In with nonce replay protection** + Keychain-backed credential persistence across reinstalls.
- **Firebase App Check** (DeviceCheck on iOS) for API abuse prevention.
- **Custom rate limiting** — client-side (5/min) + server-side (10/min on comments).

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SwiftUI Views (39)                    │
│   AuthView · MainTabView · CameraView · HistoryView      │
├─────────────────────────────────────────────────────────┤
│             @Observable ViewModels (8)                   │
│   CameraVM · HistoryVM · FriendsListVM · ChatVM · …      │
├─────────────────────────────────────────────────────────┤
│            Repository Protocols (DI-friendly)            │
│   PhotoRepository · FriendsRepository · …                │
├─────────────────────────────────────────────────────────┤
│             Swift Actors (16 services)                   │
│   AuthService · StorageService · PhotoService · …        │
├─────────────────────────────────────────────────────────┤
│                  Infrastructure                          │
│  Firebase · SwiftData · App Group · NWPathMonitor        │
├─────────────────────────────────────────────────────────┤
│        Widget Extension · Notification Service           │
│        watchOS App · macOS Admin (separate target)       │
└─────────────────────────────────────────────────────────┘
```

**Pattern:** MVVM + Repository + Dependency Injection
**Concurrency:** Swift 6 strict, `actor` for all services, `@Observable` for view models, `OSAllocatedUnfairLock` for the DI container
**Thread safety:** Verified — no `@unchecked Sendable` shortcuts, no warnings

---

## ⚙️ Tech Stack

| Layer | Tech |
| --- | --- |
| **UI** | SwiftUI (iOS 17+ APIs), UIKit bridges where needed |
| **Concurrency** | Swift 6 strict, `async/await`, `actor`, `@Observable` |
| **Local persistence** | SwiftData (offline cache), Keychain (auth), App Group (widget data) |
| **Backend** | Firebase — Firestore, Storage, Auth, Cloud Messaging, App Check, Crashlytics, Analytics |
| **Cloud Functions** | TypeScript/JS, `firebase-functions` v2, `firebase-admin`, `jimp`, `@google-cloud/vision` |
| **Camera** | AVFoundation custom pipeline, HEVC video, parallel capture + GPS |
| **Widgets** | WidgetKit + App Intents (iOS 18 interactive widgets) |
| **Live Activity** | ActivityKit (upload progress, Dynamic Island) |
| **Watch** | WatchKit + WatchConnectivity |
| **Notifications** | UserNotifications + Notification Service Extension (rich previews with avatars + thumbnails) |
| **Drawing** | Custom Canvas-based overlay engine, undo/redo, image burn |
| **Networking** | Native `URLSession`, `URLCache` (50MB RAM + 150MB disk) |
| **Security** | App Check (DeviceCheck), per-user FCM token private subcollection, nonce replay protection |

---

## 🧩 Feature Matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Camera capture | ✅ | Front/back, flash, exposure, lens zoom, WYSIWYG |
| Video recording | ✅ | Long-press shutter, HEVC, progress ring |
| Drawing overlay | ✅ | Canvas, color/brush, undo/redo |
| Text overlay | ✅ | Draggable, burns into image |
| Photo history | ✅ | Grid + date groups, pagination, offline-first |
| Streak system | ✅ | Server-side, 5 tiers, friendship score |
| Daily prompts | ✅ | 60 prompts, Cloud Function, topic push |
| DM | ✅ | Reply chain, typing, read receipts, reactions, photo/video bubbles |
| Comments | ✅ | Real-time, reply thread, server rate-limited |
| Invite code + QR | ✅ | Camera-based QR detection |
| Widgets | ✅ | Small/Medium/Large + Lock Screen |
| Dynamic Island | ✅ | Upload progress + status |
| Push notifications | ✅ | 6 types, per-user silent hours, rich previews |
| Watch app | ✅ | Recent photos, streak display |
| Apple Sign-In | ✅ | Nonce-protected, Keychain-persisted |
| Content moderation | ✅ | Cloud Vision SafeSearch |
| GDPR/KVKK delete | ✅ | 9-step cascade, client + server |
| In-app banner | ✅ | Custom overlay with deep link |
| Block / report | ✅ | Two-sided, Firestore rules-enforced |

---

## 📁 Project Structure

```
StripMate/
├── App/                   # @main entry, lifecycle, root container
├── Core/
│   ├── Views/             # 39 SwiftUI screens
│   ├── ViewModels/        # 8 @Observable view models
│   ├── Services/          # 16 actor-based services
│   └── Camera/            # Custom AVFoundation pipeline
├── Models/                # 15 Codable / SwiftData models
├── Utils/                 # Haptics, formatters, image processing
└── Resources/             # Assets, sounds, localization

StripMateWidget/           # Widget Extension (3 sizes + Lock Screen)
StripMateNotificationService/  # Rich notification previews
StripMateWatch Watch App/  # watchOS companion
functions/                 # Firebase Cloud Functions (TS)
```

---

## 🛠️ Setup

This repo is published as a **portfolio / reference implementation**. Running it end-to-end requires your own Firebase project + Apple Developer team.

### Prerequisites

- Xcode 16+ (Swift 6 toolchain)
- iOS 17+ device or simulator
- Firebase project (Firestore, Storage, Auth, Functions, App Check)
- Apple Developer account (for push, App Check, Sign in with Apple)

### Steps

1. Clone:
   ```bash
   git clone https://github.com/clbasaran/anlik.git
   cd anlik
   ```
2. Create a Firebase project and download your own `GoogleService-Info.plist` into `StripMate/App/`.
3. Update bundle identifier and Team ID in Xcode project settings.
4. Deploy Cloud Functions:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```
5. Open `StripMate.xcodeproj` in Xcode 16+ and build.

---

## 📚 Engineering Decisions Worth Reading

A few non-obvious choices documented in commit messages and docs:

- **Why actors over GCD:** [`StripMate/Core/Services/`](StripMate/Core/Services/) — all services are isolated actors, eliminating an entire class of race conditions
- **Why server-side streak math:** clients can lie about the calendar. Daily streak verification happens in a Cloud Function with the server's clock + timezone awareness
- **Why Firestore persistent cache + SwiftData:** Firestore handles real-time sync; SwiftData mirrors what's been seen for instant offline reads. Different responsibilities, both needed
- **Why 1080p resize + JPEG 0.75:** ~80% upload size reduction with imperceptible quality loss for social photos
- **Why per-user silent hours (default off):** the original implementation hard-coded silent hours 23:00–07:00 globally; this killed notifications for night-shift users. Now opt-in per user

See [`docs/`](docs/) for deeper writeups (Turkish):
- [`01_TEKNIK_MIMARI.md`](docs/01_TEKNIK_MIMARI.md) — Technical architecture
- [`02_GUVENLIK_GIZLILIK.md`](docs/02_GUVENLIK_GIZLILIK.md) — Security & privacy
- [`07_FIRESTORE_CLOUD_FUNCTIONS.md`](docs/07_FIRESTORE_CLOUD_FUNCTIONS.md) — Backend deep-dive

---

## 🧪 Testing

- ~993 lines of unit tests, ~47 cases
- Test targets: `StripMateTests` (unit), `StripMateUITests` (UI smoke)
- Run: `⌘+U` in Xcode, or `xcodebuild test -scheme StripMate -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## 🚧 What's Not in This Repo

- `GoogleService-Info.plist` — bring your own
- App Store provisioning profiles + signing certs
- Push notification `.p8` key

---

## 🎓 What I Learned Building This

Honest reflection — I shipped this as my first real iOS project. A few non-trivial takeaways:

1. **Swift 6 strict concurrency forces you to think.** When the compiler refuses to ship a data race, you can't paper over it. The mental model shift from "threads + locks" to "isolation domains" took weeks but is worth it.
2. **You don't need every feature on day one.** I shipped widgets, watchOS, and Live Activity before I knew if anyone wanted the core product. Should have stayed focused.
3. **Server-side truth beats client-side cleverness.** Anything users can game (streak, friendship score, prompts) must live on the backend.
4. **Cloud Vision + App Check + Firestore Rules** is a surprisingly small amount of code for a real moderation/abuse stack — but only if you compose them right.
5. **The hardest part isn't Swift.** It's the product decisions: which feature to ship, which to delete, when to listen to the user vs. your own taste.

---

## 📬 Contact

Built by **Celal Başaran** — solo iOS developer, Turkey.

- 🌐 [celalbasaran.com](https://celalbasaran.com)
- 📧 celalba78@icloud.com
- 💼 [LinkedIn](https://linkedin.com/in/clbasaran)
- 🐦 [Twitter/X](https://twitter.com/clbasaran)

Open to **junior / mid iOS engineer** positions in Turkey (Istanbul, hybrid, or remote).

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

> _**"Filtreler değil, anlar."**_
> _Not filters. Moments._
