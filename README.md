# GymNotes

Offline workout tracker built with Flutter.

## Pricing model
- Completely free app.
- No subscriptions, in-app purchases, ads, or paywalled features.

## Core features
- Strength workouts and templates
- Cardio workouts and interval templates
- Scheduling with reminders
- Two-way sync between scheduled items and linked workouts
- Backup export/import (JSON)
- Workout PDF export/import
- Auto progression tuning controls
- Advanced exercise progress statistics

## Development
```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

## Publishing (Android)
1. Prepare signing (`android/key.properties`, keystore file).
2. Set app metadata:
- `pubspec.yaml` `description` and `version`
- `android/app/build.gradle.kts` `applicationId` + `namespace`
3. Run pre-publish validation:
```bash
# Windows
.\android\gradlew.bat -p android app:prepublishCheck
# macOS/Linux
./android/gradlew -p android app:prepublishCheck
```
4. Build artifacts:
```bash
flutter build apk --release
flutter build appbundle --release
```
5. Publish policy/metadata:
- Host [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) at a public URL.
- Complete all items in [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).
