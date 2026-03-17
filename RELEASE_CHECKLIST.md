# Release Checklist (Android First)

## 1) One-time metadata
- [ ] Confirm Android `applicationId` in `android/app/build.gradle.kts` is your final package id (currently `com.gymnotes.app`).
- [ ] Confirm `namespace` in `android/app/build.gradle.kts` matches the final package id.
- [ ] Update `pubspec.yaml`:
  - [ ] `description`
  - [ ] `version` (`x.y.z+build`)
- [ ] Update `README.md` app description and setup notes.

## 2) Signing
- [ ] Create upload keystore (`.jks`).
- [ ] Copy `android/key.properties.example` to `android/key.properties`.
- [ ] Fill real values in `android/key.properties`.
- [ ] Keep keystore and `key.properties` out of source control.
- [ ] Run `app:prepublishCheck` (`.\android\gradlew.bat -p android app:prepublishCheck` on Windows).

## 3) Quality gates
- [ ] `flutter pub get`
- [ ] `flutter test`
- [ ] `flutter analyze` (no errors; warnings can be triaged)

## 4) Build artifacts
- [ ] `flutter build apk --release`
- [ ] `flutter build appbundle --release`
- [ ] Verify outputs:
  - [ ] `build/app/outputs/flutter-apk/app-release.apk`
  - [ ] `build/app/outputs/bundle/release/app-release.aab`

## 5) Device QA pass
- [ ] Fresh install on physical Android device.
- [ ] Verify startup, workout create/edit/delete, schedule sync both ways.
- [ ] Verify notifications/reminders, backup export/import, PDF export/import.
- [ ] Verify app upgrade path from previous installed build.

## 6) Play Console prep
- [ ] Privacy policy URL.
- [ ] App icon, screenshots, feature graphic.
- [ ] Data safety form.
- [ ] Content rating.
- [ ] Internal testing track upload (`.aab`).
