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
Risks / follow-ups: a tiny UTF-8 file with one bad byte can fall under 99% (fixture has 871 non-ASCII bytes). A vCard whose quoted-printable text (with bytes above 0x7F) declares an unsupported charset such as GB2312 or Big5 now returns ImportIssue.unsupportedCharset with a message in five languages (corpus file vcard_gb2312_qp.vcf); a declared but unsupported charset on plain ASCII text is accepted.

Task: 1.17 (b) and (c)  Status: UNVERIFIED
Callers checked: hitFor is called from home.dart and phone_home.dart for every drawn row; _hits is assigned only in setQuery and _runSearch.
Failing test: test/hit_for_test.dart checks behaviour only (written, not run); no timing test.
Change: hitFor reads an identity map built once per search; TextOps.title and squash reuse compiled RegExps.
verify.sh: not run
Risks / follow-ups: 1.17(a), the full index rebuild on the UI thread during refresh, is not done. It needs the index build moved off the UI thread or made incremental, and the 10k-contact perf test.

Task: 1.8  Status: UNVERIFIED
Callers checked: Tabular.classifyHeader is used by the table importer and by the JSON importer in codec.dart (which has a default branch, so the new Col.tags is ignored there); the only exhaustive switch over Col is Tabular.toPeople.
Failing test: test/headers_test.dart with Google and Outlook header rows (written, not run; the headers are typed from memory of the real exports, not from a corpus file)
Change: new Col.tags for Labels, Group Membership, Categories, Tags and the Arabic, Chinese, French and Spanish equivalents, split on ::: and ;, system labels starting with * dropped, stored in Person.groups. Organization Title maps to job title and Organization Department is ignored. A plain Title column is ignored when the file also has a Job Title column.
verify.sh: not run
Risks / follow-ups: the corpus of real exports from the plan does not exist yet. TableMapping.describe does not mention labels because its words are not translated.

Task: 1.3  Status: UNVERIFIED
Callers checked: Xlsx.read is still used by the Numbers fallback in codec.dart and by existing tests; Codec's xlsx branch now calls the new Xlsx.readSheets through _fromWorkbook. The template's guide sheet is not picked up because the first sheet already has phone and email columns.
Failing test: test/xlsx_read_test.dart (written, not run). The new regexes were run in Python on the same XML (prefixed workbook, self-closing row, sheet targets, padded number) and gave the expected rows.
Change: every element pattern accepts an optional namespace prefix (row, c, v, si, t, rPh, sheet, Relationship, numFmt, cellXfs, xf); self-closing rows no longer swallow the next row; all sheets are read in workbook order; when the first sheet has no phone or email column and yields no contacts, the first sheet that does is used and its name is appended to ImportResult.detail; numbers in a cell style with a format of two or more zeros get their leading zeros back.
verify.sh: not run
Risks / follow-ups: the sheet name is stored in detail but no screen shows it yet, and the review-screen flag "N numbers may have lost a leading 0" is not built; both need new strings in five languages. A number cell with no zero-padded format still loses its zero.

Task: 1.18  Status: UNVERIFIED
Callers checked: AppState.plan and the old dedupe both used Person.phoneKeys; both now use the new Person.matchKeys (phone keys plus lowercased email). Settings was the only caller of dedupe().
Failing test: test/dedupe_test.dart (written, not run)
Change: re-imported email-only rows now match existing contacts; Settings dedupe shows a confirm dialog with the count and up to five names, then a snackbar with Undo (planDedupe, applyDedupe, undoDedupe). New strings dedupePreview and dedupeMerge in five languages.
verify.sh: not run
Risks / follow-ups: matching by email can merge two different people who share a family address; this is what the plan asked for. Undo restores the kept contact from a copy taken before the merge, and re-adds the removed ones with their original ids.

Task: 1.19  Status: UNVERIFIED
Callers checked: ReviewScreen is pushed from WorkspaceRoot._receive and from the import sheet; ImportPlan is built only in AppState.plan and ReviewScreen._commit.
Failing test: test/review_screen_test.dart (written, not run)
Change: the add count is computed from the rows actually kept, so skipped duplicates no longer distort it when merge is toggled; a failed commit resets the spinner and shows the new importFailed message; the 400-row cap is gone so every row can be skipped; double taps on the button are ignored while saving.
verify.sh: not run
Risks / follow-ups: Phase 2.4 rebuilds this screen. A commit that fails after saving some rows leaves those rows saved; the store has no transaction.

Task: 1.20  Status: UNVERIFIED
Callers checked: Codec.table is called by Codec.encode and the export screen preview (now passes the format); VCard.write is called by Codec.encode, the journal snapshot (lossless) and reach_ui sharing; ExportOptions is built in app_state and the export screen.
Failing test: test/export_fields_test.dart (written, not run)
Change: ExportOptions.includeTitle and includeGroups (null means the format default: off for CSV, on for the others); Job Title and Groups columns appear only when someone has the data and sit before contact_id; vCard always writes TITLE and now writes CATEGORIES outside lossless mode when groups are included; JSON gets job_title and groups; import recognises Groups, Job Title and their Arabic, Chinese, Spanish and French headers; export screen has two new toggles and localized headers.
verify.sh: not run
Risks / follow-ups: the JSON importer now reads job_title and groups as well (Col.title and Col.tags in the flattened-key switch). Existing tests that compare exact CSV headers should be rechecked for people that have a job title or groups.

Task: 1.9  Status: UNVERIFIED
Callers checked: LibraryStore.load and migrate were the only readers of library rows; Journal.load the only reader of journal rows; AppState.init was the only place that swallowed an open failure; main.dart builds MaterialApp.
Failing test: test/migration_test.dart (corrupt row now lands in quarantine, new stored v2 sample, current-schema corrupt rows), test/store_failure_test.dart (written, not run). store_failure_test relies on Hive.initFlutter throwing in a plain test environment because path_provider has no plugin there; if it does not throw, that test needs a different way to force a failed open.
Change: unreadable library and journal rows move to the quarantine_v1 Hive box (key library:<key> or journal:<key>); Settings shows "N items couldn't be read" with a tap to share them as raw JSON; if the library fails to open, a blocking error screen with Try again replaces the app and every write throws instead of doing nothing.
verify.sh: not run
Risks / follow-ups: the quarantine box is also excluded from cloud backup because it lives in app_flutter. The error screen was not checked on a device; it shows through ContactFlowApp, so widget tests that pass an explicit home are unaffected.

Task: 1.6  Status: UNVERIFIED
Callers checked: the five places named in the plan (PhoneSource._name, VCard.splitName, NameParts.of, SwapName, TemplateName); MessageTemplate.render also goes through NameParts.of so it changed too.
Failing test: test/name_split_test.dart with 9 clear and 12 unclear names, run through NameSplit, NameParts, VCard.splitName and PhoneSource.nameFor, plus vCard, SwapName and TemplateName cases (written, not run).
Change: new NameSplit in lib/domain/names.dart. A name containing Arabic script, or an Arabic particle written in Latin letters (bin, ibn, bint, abu, abo, abd, abdul, abdel, abdal anywhere; al, el, ul or al-/el- forms after the first word), is not split: the phone write puts it all in the given name, vCard writes N:;full;;;, SwapName skips it and the batch preview says how many were left as they are (new string swapSkipped), and TemplateName puts the whole name in {first} with an empty {last}. Latin and Chinese names behave as before.
verify.sh: not run
Risks / follow-ups: "Al Pacino" still splits because al is only treated as a particle after the first word; "Al Harbi" therefore splits as first Al, last Harbi. A Latin name with a Spanish or Dutch particle in the middle, such as "Omar El Sayed" or "Ana el Amrani", is now kept whole.

Task: 1.14  Status: UNVERIFIED (partly done)
Callers checked: _groupIds is read in _toPerson, groups(), _groupId and _syncGroups; PhoneBook.groupNames reads groups().
Failing test: test/group_keys_test.dart covers the key and system-group helpers only (written, not run). The account-keyed behaviour needs an emulator with a Google account and a device-only group both called "Family".
Change: groups are keyed by account then name, so a contact in a Google account only sees and joins that account's group; system groups ("My Contacts", "Starred in Android", ICE, and names starting "System Group") are skipped, which also skips the biggest membership query; groups with a contact count of 0 are not queried.
verify.sh: not run
Risks / follow-ups: not done: the plan's single membership query. flutter_contacts 2.1.0 has no group property on contacts and only ContactFilter.group, so membership still costs one getAll per non-empty group on every refresh. Doing it in one query needs a small native channel over ContactsContract.Data (GROUP_MEMBERSHIP). The system-group list is English only and cannot see localized names such as a translated "My Contacts". Phase 4c depends on this.

Task: 1.10  Status: UNVERIFIED
Callers checked: Codec.decode (wrapper), decodeInBackground (home/root receive, import sheet picker, import sheet paste), Xlsx and NumbersFile (the only ZipDecoder users).
Failing test: test/corpus_test.dart (16 corpus files from test/corpus, generated by script), test/fuzz_decode_test.dart (500 random blobs and 500 corrupted real files), test/zip_guard_test.dart, test/jobs_test.dart, test/perf/decode_size_test.dart (1M-line txt, 50k CSV, 50k XLSX, 5 MB of vCard photos) (all written, not run).
Change: ZipGuard refuses a zip whose declared unpacked size is over 200 MB (new issue tooLarge) before any entry is unpacked; every decode now runs in an isolate with a 20 s timeout and a CancelToken, killing the isolate on timeout or cancel (new issues timedOut and cancelled; strings in five languages); the paste path now decodes in the background too; the file picker reads from the file path instead of loading everything with withData, and files over 64 MiB are refused; the CSV parser now treats a quote after leading spaces as an opening quote and detects the delimiter in old-Mac \r files.
verify.sh: not run
Risks / follow-ups: the corpus has no real Samsung, iPhone, Google Sheets, LibreOffice or Numbers exports; iphone_style.vcf, samsung_style.vcf, google_contacts.csv and outlook.csv were written by hand in those styles, so real files still need to be dropped into test/corpus. The sheet UI has no visible Cancel button yet: closing the sheet cancels the decode. test/harness.dart sets decodeInIsolate = false so widget tests decode inline; jobs_test turns it on. If the iPhone vCard test fails on grouped properties (item1.TEL), that is a real parser gap to fix in vcard.dart.


Task: 1.7  Status: UNVERIFIED (own branch: phase-1-7)
Callers checked (grep of the old key and key-set logic): Phones.key (now delegates to PhoneKey.key), Person.phoneKeys and matchKeys, Person.absorb, Matcher (index build, rowsPerKey, _matchRow), Merger.unionPhones and findDuplicates, NumberCheck.inspect, Reach.copyList, DedupeNumbers batch op, AppState.plan and planDedupe, the removed DeviceContacts.writeAll.
Failing test: test/phone_key_test.dart (12 regions from the package's own example numbers, plus extensions, Arabic-Indic digits, 00 prefixes, BH 8-digit, formats, regions and a no-regression table), test/region_test.dart, additions to test/dedupe_test.dart and test/batch_ops_test.dart (all written, not run). The old tests that assumed a forced trunk zero or a hand-grouped spaced format were updated.
Change: new lib/phone/phone_key.dart on top of phone_numbers_parser 9.0.28. A number is explicit when it starts with + or 00 and parses as valid, and then carries an E.164 value; every other number is local. The index key is still the last 9 digits, now of the national number, with extensions removed, so every pair the old key matched still shares a key. Two explicit numbers only match when their E.164 values are equal, so the same national number in two countries no longer matches; a local number still matches either by its national part. Region: new region preference (ISO code), migrated from the old calling-code preference when the code is unique, with a picker for shared codes (+1, +7, +44); at startup with no setting the SIM country (new contactflow/device channel) and then the locale are used. InternationalNumber uses the parsed value when the number is explicit or when the entered country matches the active region.
verify.sh: not run
Risks / follow-ups: pubspec.yaml now needs phone_numbers_parser but pubspec.lock was not updated; run `flutter pub get` and commit the lockfile (CI uses --enforce-lockfile and will fail until then). The country list in the picker shows ISO codes with flags, not country names. Parsing 20,000 numbers on first use may take a second on the UI thread (NumberStats and the matcher build their keys there); the plan's isolate for the index build and the APK size comparison (+2 MB budget) are not done. The merge and sync isolates do not receive the region, so local numbers inside them fall back to the old last-9 key until their job classes carry the region. The e164 batch format still strips spaces only and does not validate. Keys are not persisted, so nothing needs migrating in the library.

Task: 1.5  Status: UNVERIFIED (branch: phase-1-7)
Callers checked: ExportScreen._toPhone was the only caller that builds CreateChange for the phone; DeviceContacts.writeAll had none and was deleted.
Failing test: test/phone_dupes_test.dart (written, not run). An end-to-end widget test that saves the same list twice through ExportScreen is not written.
Change: PhoneDupes.split drops people whose number (compatible country) or email is already in PhoneBook.people; a dialog says how many are already on the phone and offers to skip them or save them anyway (new strings in five languages).
verify.sh: not run

Task: 1.15  Status: UNVERIFIED (branch: phase-1-7)
Callers checked: AddCountryCode, RemoveCountryCode and FormatNumbers are only built in batch_screen.dart; the addTrunkZero parameter is kept for source compatibility and no longer used.
Failing test: updated and new cases in test/batch_ops_test.dart (written, not run)
Change: Add uses E.164 from the parser for local numbers and leaves explicit numbers alone (00 becomes +); Remove gives the national format only for numbers of that country, so Spanish and Chinese numbers get no leading zero and Italian numbers do not gain a second one; Spaced uses international format for explicit numbers and national format for local ones, grouped from the front; extensions are kept as ' x12'; numbers that cannot be read are left alone and the preview says how many contacts were skipped (new string numbersUnread).
verify.sh: not run
Risks / follow-ups: with no region set, Spaced leaves local numbers alone because they cannot be parsed. The remaining behaviours depend on the package's metadata and the national-prefix formatting rule lookup, which uses dynamic access to unexported metadata types.

Task: 2.6  Status: UNVERIFIED (branch: phase-1-7, it was done last)
Callers checked: L.n is called from phone_actions, sync_screen, queue_screen, batch_screen; only contacts, numbers and selected got the full six forms, the rest fall back to their existing singular and plural keys.
Failing test: test/l10n_test.dart (Arabic form table 0..1011, presence of all forms, {n} rules, n() output; written, not run). The old blanket skip of Arabic _one keys was replaced by a check that the Arabic singular only uses placeholders English has.
Change: L.arabicForm returns zero, one, two, few (3-10 mod 100), many (11-99 mod 100) or other; n() looks up <many>_<form> for Arabic and falls back otherwise.
verify.sh: not run
Risks / follow-ups: the other plural pairs (rowsN, willDeleteN, noNumberN, opApplied, updatedN) still use the two-form fallback in Arabic; Phase 2.6 asks for all of them to get Arabic forms over time. Chinese has no plural forms and English, Spanish and French are unchanged.

Task: 3 (number pattern core)  Status: UNVERIFIED, NOT INTEGRATED (branch: phase-1-7)
Callers checked: none yet; nothing calls the new module.
Failing test: test/number_pattern_test.dart (48 parser cases, matching, chips, AND/OR, tags, highlights, forms; written, not run). The parser and scorer were ported to Python and run on the same cases, all agreed.
Change: lib/search/number_pattern.dart adds NumberQuery.parse and score, NumberAtom, TagAtom, TextAtom, DigitMode (anywhere, ends, starts, contains), PhoneForms (saved, national and E.164 digits per number, extensions removed) and highlights. Arabic and full-width ? , * # + and digits are normalised first. A query made only of digits, spaces, dashes and brackets is one number. Plain digits are ranked exact 4, ends 3, starts 2, contains 1; wildcard patterns score 3; AND needs one number to satisfy every number atom; comma is OR; a # atom needs the hasTag callback.
verify.sh: not run
Risks / follow-ups: not done: wiring into ContactList and both workspaces, the chips and help sheet, recent searches and Save as smart filter, the per-number precomputed index (PhoneForms is computed per call), the speed tests (10k contacts / 20k numbers, p95 under 8 ms, 16 ms per keystroke) and moving fuzzy search off the UI thread. Mixed text and number queries are parsed (TextAtom plus NumberAtom) but the caller still has to combine the fuzzy name score with NumberQuery.score.


Task: 3 (search integration)  Status: UNVERIFIED (branch: phase-1-7)
Callers checked: ContactList._runSearch is the only search entry; both workspaces read ContactList.hits; the index is rebuilt in replacePeople.
Failing test: test/pattern_search_test.dart (12 cases through AppState: wildcards, tags via groups, OR, name plus pattern, digit chips, edit invalidation, region, matchedPhone; written, not run)
Change: PatternSearch (lib/search/pattern_search.dart) scores contacts with NumberQuery, caches PhoneForms per contact keyed by the contact's numbers, and combines a name part with the fuzzy index. ContactList uses it when the query has a tag, a wildcard, a leading plus, a comma, or a digit chip other than "anywhere"; plain digits and names still use the fuzzy path. ContactList.digitMode and setDigitMode are ready for the chips. Tags currently match group names, case-insensitively, until Phase 4 adds number tags.
verify.sh: not run
Risks / follow-ups: no chips, help sheet, recent searches or Save as smart filter in the UI yet; no highlight of the matched digits in rows; the speed tests (10k contacts, 20k numbers, p95 under 8 ms) are not written and PhoneForms for 20k numbers is built on the UI thread on the first pattern search.


Task: 3 (search UI)  Status: UNVERIFIED (branch: phase-1-7)
Callers checked: both workspaces build their own search bar (home.dart and phone_home.dart); both extend ContactList.
Failing test: test/search_chips_test.dart (written, not run)
Change: lib/ui/search_extras.dart adds DigitModeChips (Anywhere, Ends with, Starts with, Contains; shown only for a digits-only query), a help bottom sheet and a help button that replaces the empty spacer at the end of each search bar. Strings in five languages (digit* and searchHelp*).
verify.sh: not run
Risks / follow-ups: the plan's other pieces are still open: recent searches under the field, Save as smart filter, the highlight of matched digits, and an RTL and 300 px overflow check of the chip row. The help button is 48 px wide where a 12 px spacer used to be, so the search field is narrower; check the existing goldens and overflow tests.
