# Critter 🐾
**Squash your tasks.**

Critter is a cross-platform Flutter to-do app backed by Firebase. It lets users create, organise, and complete tasks with due dates, categories, repeat schedules, and local push notifications — all synced in real time across devices.

---

## Features

| Feature | Details |
|---|---|
| **Authentication** | Email / password sign-up, login, and password reset via Firebase Auth |
| **Real-time sync** | Tasks stored in Cloud Firestore, streamed live to the UI |
| **Task management** | Add, complete, and delete tasks with title, notes, category, due date, and repeat frequency |
| **Categories** | Filter tasks by General, Work, School, or Personal |
| **Smart grouping** | Tasks automatically sorted into Overdue, Today, This Week, Later, and Completed sections |
| **Repeat tasks** | Daily, weekly, and monthly repeat — auto-reschedules on completion |
| **Push notifications** | Local notifications fire at the task's due date/time (Android) |
| **Calendar view** | Monthly calendar highlights days with tasks; tap a day to see its tasks |
| **Error feedback** | Firebase and notification errors surface as SnackBars instead of failing silently |

---

## Tech Stack

- **Flutter** (Dart) — UI framework
- **Firebase Auth** — user authentication
- **Cloud Firestore** — real-time NoSQL database
- **flutter_local_notifications** — scheduled push notifications
- **table_calendar** — calendar widget
- **uuid** — unique task IDs

---

## Project Structure

```
lib/
├── main.dart                  # App entry point, Firebase init, auth routing
├── firebase_options.dart      # Auto-generated Firebase config
├── models/
│   └── task.dart              # Task model, toMap/fromMap, repeat logic
├── screens/
│   ├── login_screen.dart      # Sign-up / login / password reset UI
│   ├── main_screen.dart       # Bottom nav shell (Tasks + Calendar)
│   ├── task_screen.dart       # Main task list with filtering and grouping
│   └── calendar_screen.dart   # Monthly calendar view
├── services/
│   ├── auth_service.dart      # Firebase Auth wrapper
│   └── notification_service.dart  # Local notification scheduling
└── widgets/
    └── add_task_sheet.dart    # Bottom sheet for creating new tasks
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10
- A Firebase project with **Authentication** (Email/Password) and **Firestore** enabled
- Android SDK (for Android builds)

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/Alexander-Chavez97/To-Do-App.git
   cd To-Do-App
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Connect Firebase**
   - Install the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)
   - Run `flutterfire configure` and select your Firebase project
   - This generates `lib/firebase_options.dart` automatically

4. **Run the app**
   ```bash
   flutter run
   ```

### Building a Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Firebase Security Rules

Firestore rules should restrict each user to their own data:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/tasks/{taskId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## Known Limitations

- iOS notification support is not yet configured
- No offline-first write queue — failed writes show an error and must be retried
- Release APK is currently signed with debug keys; production releases should use a proper keystore
