## Repo snapshot

- Flutter app (lib/) using Hive for local storage with generated adapters (see `lib/models/*` and `*.g.dart`).
- Localization in `lib/l10n/` (ARB input `app_en.arb`, generated `l10n.dart`).
- UI pages live in `lib/pages/`; background helpers and integrations in `lib/services/` (e.g., `export_service.dart`).

## High-level architecture (what matters to an agent)

- Single Flutter app (Material3). Entry: `lib/main.dart` — it registers Hive adapters and opens named boxes: `workouts`, `sets`, `templates`, `exercises`, `settings`.
- Data layer: Hive models are defined in `lib/models/` and code-generated adapters exist (`*.g.dart`). Use `build_runner` + `hive_generator` for model updates.
- UI layer: `lib/pages/` contains screens and navigation. `RootNav` (in `main.dart`) orchestrates top-level tabs.
- Services: `lib/services/` contains cross-cutting functionality. Example: `export_service.dart` builds PDFs (uses `pdf` + `printing`) and embeds a Base64 payload between sentinel tags `[[WL-EMBED:...]]` so the app can later extract/import workout data.

## Project-specific conventions & patterns

- Persistence: Always use Hive boxes; model adapters are registered in `main.dart`. When adding a new model, create the model class, add `part 'xxx.g.dart'`, and run build_runner to generate the adapter.
- Codegen: Dev deps include `build_runner` and `hive_generator` (see `pubspec.yaml`). Typical command:

  flutter pub get
  flutter pub run build_runner build --delete-conflicting-outputs

- Exports & sharing: `export_service.dart` exposes functions like `shareWorkoutPdf`, `shareWorkoutImage`, `saveWorkoutPdfToDevice`, `extractEmbeddedFromPdf`, `importPayloadFromPdfBytes`. Look there for PDF embedding/extraction details and the embed sentinel `_kEmbedStart/_kEmbedEnd`.
- File selection/saving: Desktop/desktop-like flows use `file_selector` and `file_saver` packages; mobile uses platform plugins (`share_plus`, `printing`). When saving, code uses `fs.getSaveLocation()` and `XFile.saveTo(location.path)`.
- Localization: Use `AppLocalizations` (generated). Strings are referenced via `AppLocalizations.of(context)`.
- Seeding: `main.dart` contains a seed block for exercises — tests or CI that create initial data may rely on it.

## Build / run / test commands (developer flows)

- Install dependencies: `flutter pub get`
- Generate adapters: `flutter pub run build_runner build --delete-conflicting-outputs`
- Run app: `flutter run` (or target device: `flutter run -d windows|android|ios|chrome`)
- Tests: `flutter test`
- Android build (CI or local): use Flutter tooling or the Gradle wrapper in `android/` (`.\gradlew assembleDebug` on Windows inside `android\`).

## Integration points & external dependencies

- Hive (local DB) — adapters live in `lib/models/*.g.dart` and are registered in `main.dart`.
- PDF handling: `pdf`, `printing` — `export_service.dart` intentionally builds PDFs with `compress: false` so embedded payloads remain extractable.
- File dialogs and saves: `file_selector`, platform-specific `file_selector_*` packages, and `file_saver` for desktop targets.
- Sharing: `share_plus` for cross-platform sharing.
- Platform APIs: `path_provider` for temp directories.

## What to look for when editing code

- If touching models: update model, add/adjust `part`/annotations, then re-run build_runner. Verify adapter registration in `main.dart` and box names.
- If touching `export_service.dart`: the embed format is non-obvious but important — preserve `_kEmbedStart/_kEmbedEnd`, `compress:false` in PDF generation, and extraction logic in `_extractEmbedBlock` and `extractEmbeddedFromPdf`.
- Keep localization generation in sync when adding strings (`l10n.yaml` present). Run `flutter gen-l10n` (usually `flutter pub get` + build will pick it up because `flutter.generate: true`).

## Quick pointers (examples)

- Registering adapters (example in `lib/main.dart`):
  - `Hive.registerAdapter(WorkoutAdapter());`

- PDF embed sentinel (see `lib/services/export_service.dart`):
  - Start: `[[WL-EMBED:`
  - End: `]]`
  - Extraction helper: `_extractEmbedBlock(Uint8List bytes)`

## Tests & verification

- There is a minimal widget test at `test/widget_test.dart`. Run `flutter test` to verify.

---

If anything above looks wrong or you want extra detail for CI, Android signing, or desktop packaging, tell me which area to expand (examples: how to run codegen in CI, where to store secrets, or unit-test patterns). I'll update and iterate.
