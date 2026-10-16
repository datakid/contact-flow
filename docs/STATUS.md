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

Task: 1.12  Status: UNVERIFIED
Callers checked: MainActivity.ingest is the only reader of the launch intent; onNewIntent also goes through it.
Failing test: n/a (native, needs a device)
Change: intents launched from history and intents already consumed are ignored.
verify.sh: not run
Risks / follow-ups: check on a device that sharing a file, backing out and reopening from Recents does not offer the file again.

Task: 1.11  Status: UNVERIFIED
Callers checked: Incoming.stream had one listener (HomeScreen); replaced by Incoming.attach/detach with a buffer; the receiver now lives in WorkspaceRoot.
Failing test: test/incoming_test.dart (written, not run; it could not be shown failing first)
Change: shared files are handled on the Phone tab too, and kept if they arrive before the screen exists. The review screen is pushed on top instead of popping open screens, so edits in progress are no longer discarded.
verify.sh: not run
Risks / follow-ups: the plan's unsaved-changes prompt was replaced by not popping routes at all.

Task: 1.4  Status: UNVERIFIED
Callers checked: IncomingFile has no other users; the channel now returns path or error per file, bytes only for shared text.
Failing test: none (native copy loop cannot be unit tested here)
Change: MainActivity streams each shared file to cache/incoming on a worker thread with a 64 MiB limit; Dart reads the file and deletes it. Files older than a day are swept.
verify.sh: not run
Risks / follow-ups: the Kotlin was never compiled. Too-large files currently show the existing "unreadable" message because a new string would need all five languages. Bytes are still read on the main isolate before decoding, not inside the decode isolate as the plan asked.

Task: 1.1  Status: UNVERIFIED
Callers checked: FuzzyIndex.search is the only reader of the digit-query rule; the token fallback in _token handles name plus digits.
Failing test: test/search_digits_test.dart (written, not run)
Change: two-digit queries match numbers (also in Arabic-Indic and full-width digits); two-digit queries also still search names; "name 36" narrows by number.
verify.sh: not run
Risks / follow-ups: a two-digit query matches many contacts by design; ranking is unchanged (ends with, starts with, contains).

Task: 1.13  Status: NOT REPRODUCED (by reading source, not on a device)
Callers checked: PhoneSource.update calls flutter_contacts update with a contact fetched with name, phone, email, organization and note only.
Failing test: none written; an instrumented test needs a device
Change: none
verify.sh: not run
Risks / follow-ups: in flutter_contacts 2.1.0 the Android update re-reads the stored contact with only the properties that were fetched, and every property write is guarded by that list, so addresses, birthdays, websites and photos are left alone. Confirm on a device with a contact that has those fields. One edge remains: an organization row that has only a department and no name or title is dropped by any edit, because the app rebuilds the organization list from name and title.

Task: 1.2  Status: UNVERIFIED
Callers checked: TextDecode.bytes is used by Codec for sniffing and for vCard, CSV, JSON and text imports; VCard._decode now calls TextDecode.charset.
Failing test: test/text_decode_test.dart with fixtures cp1256_ar.csv, cp1252_fr.csv, utf8_one_bad_byte.csv, vcard21_cp1256.vcf, vcard21_cp1256_raw.vcf (written, not run). The detection rule and both tables were checked in Python against its cp1252 and cp1256 codecs; the Dart was not run.
Change: only non-ASCII bytes are counted; at least 99% valid UTF-8 means UTF-8 with bad bytes allowed; otherwise runs of two or more Arabic-letter bytes mean Windows-1256 and isolated Latin letters mean Windows-1252. Both tables are in the code. vCard CHARSET windows-1256 and windows-1252 are decoded.
verify.sh: not run
Risks / follow-ups: a tiny UTF-8 file with one bad byte can fall under 99% (fixture has 871 non-ASCII bytes). A vCard with an unsupported charset (GB2312, Big5) still falls back to UTF-8 instead of returning an ImportIssue, because a clear message needs a new string in all five languages.
