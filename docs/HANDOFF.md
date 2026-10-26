# Handoff: testing and finishing Contact Flow 3.0

The plan is in docs/PLAN.md. Everything below was written in a sandbox with no Flutter, Dart or Kotlin compiler and no push access. Nothing has been compiled, analysed or run. Treat every change as a draft that has to be proven by tool/verify.sh. docs/STATUS.md has one report per task with the exact tests that were written.

## CI workflow

The GitHub token used to push these branches could not write workflow files, so the CI workflow is stored as tool/ci.workflow.yml instead of .github/workflows/ci.yml. Copy it into .github/workflows/ci.yml (the GitHub web editor or any token with the workflow scope can do that). Until then nothing runs in CI.

## Static checks that were possible without a compiler

- tool/dart_syntax_check.py parses every Dart file with the tree-sitter Dart grammar (`python3 -m venv v && v/bin/pip install tree-sitter tree-sitter-dart && v/bin/python tool/dart_syntax_check.py plain`). All 163 Dart files in lib and test parse cleanly, and the same grammar parses all 90 original files cleanly. It caught one real slip (a dropped bracket in settings_sheet.dart) that is now fixed.
- The Kotlin files (MainActivity, both Edition.kt, CallsReader) parse cleanly with tree-sitter-kotlin.
- tool/import_check.py reports project classes used without an import and project imports that are never used. It found no missing imports; its "unused import" lines for theme.dart and harness.dart are false positives (extension members and top-level functions are not tracked).
- None of this checks types, named parameters, or whether a member exists, so expect analyzer errors of that kind.

## Branches

- phase-1 starts at 2c38c77 and holds tasks 0.3, 0.4, 1.1, 1.2, 1.3, 1.4, 1.6, 1.8, 1.9, 1.10, 1.11, 1.12, 1.14, 1.16, 1.17(b)(c), 1.18, 1.19, 1.20.
- phase-1-7 starts at the end of phase-1 and holds 1.7, 1.5, 1.15, 2.6 and the Phase 3 number pattern core. The plan wants 1.7 merged on its own, so review and merge it separately.
- Apply with `git am --keep-cr` (the fixtures contain CRLF and non-UTF-8 bytes) or fetch from the bundle.

## First steps, in this order

1. `flutter pub get` (Flutter 3.35.4). phone_numbers_parser was added to pubspec.yaml but pubspec.lock was not updated, so CI's `--enforce-lockfile` fails until the lockfile is committed.
2. `dart format .` and commit it alone (task 0.2). Many new files were formatted by hand and have lines over 80 columns.
3. `flutter analyze --fatal-infos`. Expect a handful of findings: unnecessary or unused imports, long lines, a few type errors from code that was never compiled.
4. `flutter test --exclude-tags "perf || golden"`. Fix failures one at a time, each with its own commit.
5. `flutter test --tags perf`, then `flutter build apk --debug --flavor lite`, `flutter build apk --debug --flavor full --dart-define=CALLS=true` (the first compile of the Kotlin in MainActivity.kt, the flavor sources and CallsReader.kt), `tool/check_permissions.sh`, and `flutter build web`. Every Android build and run now needs a flavor.
6. Fill in the baseline in docs/STATUS.md (task 0.1) with real output, then replace each UNVERIFIED line with FIXED or NOT REPRODUCED and paste the verify.sh result.

## Most likely to need fixing

- android/app/src/main/kotlin/com/contactflow/contacts/MainActivity.kt: async copy of shared files, intent guard, SIM country channel.
- lib/phone/phone_key.dart: the national-format lookup reads unexported metadata through dynamic access; check the SA, ES, FR, CN, US and IT cases in test/phone_key_test.dart.
- test/store_failure_test.dart assumes Hive.initFlutter throws in a plain test run.
- test/corpus_test.dart: iphone_style.vcf needs the vCard parser to understand grouped properties such as item1.TEL; if it fails the parser needs a fix, not the test.
- test/jobs_test.dart: the timeout case uses Duration.zero and relies on the timer firing before the isolate answers.
- Widget tests in test/incoming_test.dart and test/review_screen_test.dart were never run under the real binding. test/harness.dart sets decodeInIsolate = false so decoding stays inline in widget tests.
- Existing tests that compare exact export headers or exact spaced and country-code outputs were changed; recheck the rest of the suite.
- lib/data/phone_source.dart: group changes (1.14) use flutter_contacts 2.1.0 APIs read from source, not run.

## Not done

- 0.1 baseline and 0.2 format commit (need the SDK).
- 1.13: not reproduced by reading the plugin source; confirm on a device with a contact that has addresses, birthdays, websites and a photo.
- 1.14: group membership is still one query per non-empty group; the plan's single query needs a native channel over ContactsContract.Data.
- 1.17(a): the index rebuild during refresh is still on the UI thread, and there is no 10k-contact perf test.
- 1.4: files over 64 MiB show the existing unreadable text; the plan asked for decode inside the isolate rather than reading bytes on the main isolate first.
- Phase 2 except 2.6 (design tokens, navigation, lists, import review redesign, goldens, Noto test fonts).
- Phase 3 UI and speed: NumberQuery and PatternSearch are wired into ContactList (wildcards, tags as group names, OR, digit mode). Still to do: the chips and help sheet, recent searches, Save as smart filter, highlighting matched digits, the precomputed per-number index off the UI thread, and the speed tests.
- Phase 4: the data layer (lib/tags, TagBook, tests), a Tags management screen, tag chips on numbers in the phone contact detail, a tag filter in the phone workspace and tags in exports exist. Still to do: the same tag card and filter in the Files workspace, tag chips on list rows, importing tags into TagBook from Google labels or vCard CATEGORIES (they currently import as groups).
- Phase 5: the flavors, call-log reader, call grouping, filters, selection, ignore list, naming, the controller, a first Calls tab screen and Move my data exist with tests. Still to do: swipe gestures, call detail, creating a new tag from the tag-only action, RTL and narrow-screen checks, and the 500-create timing test.
- Phase 6: version 3.0.0+8, CHANGELOG.md, README What's new, store changelogs and docs/QA.md are written. Still to do: run QA.md on real phones for both builds, update the performance and APK size tables and screenshots with measured values.

## Decisions that were taken without the owner

- 1.16 backup: contacts and tags are excluded from Google backup (the plan's default). Device-to-device transfer is not restricted.
- 1.20: Job Title and Groups columns are off by default for CSV and on for XLSX and JSON.
- 5.1: the F-Droid 3.0.0 entry (version code 8, tag v3.0.0) is a guess; the full edition has no separate icon.
- 1.7: matching keeps the old last-9-digit key and only refuses two explicit numbers with different country codes, so nothing that matched before stops matching unless the codes differ.

## Conventions kept

- No code comments in any code file.
- One commit per task, named like `1-6: ...`, with a STATUS.md entry in the format from the plan.
- New user-facing strings go in all five languages: `python3 tool/add_strings.py strings.json` where strings.json maps a key to {en, ar, zh, es, fr}.
