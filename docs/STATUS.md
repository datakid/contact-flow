# Contact Flow 3.0 status

Work in this file was prepared in a sandbox that has no Flutter or Dart SDK and no push access. Nothing below has been compiled or run. Every result marked UNVERIFIED must be confirmed by `tool/verify.sh` on a machine with Flutter 3.35.4.

## Baseline (task 0.1)

Status: BLOCKED. `flutter pub get`, `flutter analyze`, `flutter test`, perf timings and APK size have not been measured.

## Open questions

- `dart format .` has not been run (task 0.2). The first CI run is expected to fail at the format step until that commit exists.
- Task 1.16 uses the plan's default (contacts and tags excluded from Google backup). This was not confirmed by the owner.

## Task reports

Task: 0.3  Status: UNVERIFIED
Callers checked: n/a
Failing test: n/a
Change: tool/verify.sh, dart_test.yaml, perf test moved to test/perf/search_perf_test.dart with the perf tag
verify.sh: not run
Risks / follow-ups: the golden step is skipped while no test file mentions the golden tag.

Task: 0.4  Status: UNVERIFIED
Change: .github/workflows/ci.yml pinned to Flutter 3.35.4
verify.sh: not run
Risks / follow-ups: the aapt permission check belongs to task 5.1.

Task: 1.16  Status: UNVERIFIED
Callers checked: Hive is initialised once in lib/services/library_store.dart (library_v1, meta_v1, journal_v1, state_v1) and writes to the app_flutter folder.
Failing test: n/a (manifest change)
Change: allowBackup with fullBackupContent and dataExtractionRules that exclude app_flutter from cloud backup; device transfer left unrestricted; README Backup section.
verify.sh: not run
Risks / follow-ups: uses the plan's default answer, not confirmed by the owner. Check on a device with `adb shell bmgr` or a restore test.
