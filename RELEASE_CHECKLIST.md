# Release Checklist

## 1) Free App Verification
- [ ] App has no in-app purchases, subscriptions, ads, or external paywalls.
- [ ] All app features are accessible without any unlock flow.
- [ ] Store listing text does not reference "Pro", "Premium", or paid upgrades.

## 2) One-Time Metadata
- [ ] Confirm Android package id in `android/app/build.gradle.kts` (`applicationId` + `namespace`) is final.
- [ ] Update `pubspec.yaml`:
  - [ ] `description`
  - [ ] `version` (`x.y.z+build`)
- [ ] Update app name/icon/screenshots for final branding.

## 3) Privacy and Compliance
- [ ] Review [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md).
- [ ] Host privacy policy at a public HTTPS URL for Play Console.
- [ ] Complete Play Console Data safety form based on actual app behavior.

## 4) Android Signing
- [ ] Create upload keystore (`.jks`).
- [ ] Copy `android/key.properties.example` to `android/key.properties`.
- [ ] Fill real values in `android/key.properties`.
- [ ] Keep keystore and `key.properties` out of source control.
- [ ] Run `app:prepublishCheck`:
  - Windows: `.\android\gradlew.bat -p android app:prepublishCheck`
  - macOS/Linux: `./android/gradlew -p android app:prepublishCheck`

## 5) Quality Gates
- [ ] `flutter pub get`
- [ ] `flutter test`
- [ ] `flutter analyze` (no errors)

## 6) Build Artifacts
- [ ] `flutter build apk --release`
- [ ] `flutter build appbundle --release`
- [ ] Verify outputs:
  - [ ] `build/app/outputs/flutter-apk/app-release.apk`
  - [ ] `build/app/outputs/bundle/release/app-release.aab`

## 7) Device QA Pass
- [ ] Fresh install on physical Android device.
- [ ] Verify startup and navigation.
- [ ] Verify workout create/edit/delete.
- [ ] Verify template create/duplicate/delete.
- [ ] Verify schedule/reminders.
- [ ] Verify backup export/import and PDF export/import.
- [ ] Verify app update path from previous build.

## 8) Play Console Submission
- [ ] Upload `.aab` to Internal testing.
- [ ] Add screenshots + feature graphic.
- [ ] Complete content rating + app category.
- [ ] Add privacy policy URL.
- [ ] Roll out to production after internal test validation.

