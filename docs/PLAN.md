# PLAN.md: Contact Flow 3.0 (revised after reading `lib/state`, `lib/batch`, most of `lib/ui`, `lib/domain` and `lib/data`)

## What changed since the first draft

This time I read every file in `lib/state/` and `lib/batch/`, most of `lib/ui/`, all of `lib/domain/` and `lib/data/`, plus the test folder, the Gradle file and the F-Droid recipe. Some of that changes the first draft:

1. **Phase 0 can't be green "without code changes."** The code isn't `dart format`-clean. For example, `home.dart` has `color: h?.reason == 'alias' ? p.accentText : p.sageText,` and `phone_home.dart` has `style: TextStyle(color: p.accentText, fontWeight: FontWeight.w800),`. Both are over 80 columns. So `--set-exit-if-changed` fails on day one. Phase 0 now starts with a commit that only formats.
2. **`test/perf/` doesn't exist.** The perf test is `test/perf_test.dart`. It only prints timings and checks nothing. No golden tests or tags exist yet either.
3. **Tasks 1.5 and 1.6 may target dead code.** I found no caller of `DeviceContacts.writeAll` in the files I read. The live "save to phone" path is `ExportScreen._toPhone` → `ChangeSet` → `PhoneSource.create`. That path doesn't check for duplicate numbers at all. `PhoneSource._name` has the same Arabic surname split, but it does write nickname, note and title. Both tasks now go to the live path.
4. **The "country" setting is a calling code, not a region.** `AppState.country` is free text like `+966`, and `InternationalNumber.of` and `Reach` read it as digits. Task 1.7 now has to migrate this setting.
5. **The 99% UTF-8 rule in 1.2 would break Arabic files.** A Windows-1256 CSV is mostly ASCII digits and commas, so it can be more than 99% "valid UTF-8" even though every Arabic name in it is invalid. The rule now only counts non-ASCII bytes.
6. **"Phone key" logic is copied in at least 7 places.** `Phones.key`, `NumberCheck.inspect`, `Merger.unionPhones`, `DedupeNumbers`, `Reach.copyList`, `Person.absorb` and `AppState.plan/dedupe` all compute it. Task 1.7 must replace all of them, not just `Phones.key`.
7. **New bugs I suspect:** shared files can be silently lost; the batch tool "Remove country code" breaks Spanish, US, Italian and Chinese mobile numbers; Outlook's "Title" column becomes the job title; contacts are included in Google cloud backup; library writes are silently dropped if Hive fails to open. These are tasks 1.11 to 1.20.

## Decisions

**1. Call history needs a second build of the app.** Reading call history needs `READ_CALL_LOG`. [Google Play only allows it](https://support.google.com/googleplay/android-developer/answer/10208820) for default phone, SMS or assistant apps, and lists contacts management as not allowed. So the plan adds a separate `full` build. The `lite` build stays exactly as it is today and stays Play-safe.

**2. The full build gets its own app ID (`com.contactflow.contacts.full`).** F-Droid gives one listing per app ID, and Android won't let two builds share one ID with different permissions cleanly. The catch: the two builds have separate storage. Someone moving from lite to full has to carry their library over with export and import. The plan adds a one-tap "Move my data" export for this.

**3. Samsung's call tags can't be imported directly.** They live in the Samsung Phone app's private storage. What can be imported: contact groups, Google CSV `Labels`, and vCard `CATEGORIES`. A test capped at 2 hours confirms this on a real phone.

**4. Ideas I'm rejecting:** deleting call-log entries, cloud sync or spam lookup, full regex search, auto-guessing names, and switching from Hive to `hive_ce` in this release.

**One decision for you (default in brackets):** should contacts and tags be left out of Android's automatic Google Drive backup? [Yes, leave them out. A user who wants a backup can export.] Today the manifest has no `allowBackup` setting, so Android backs up the Hive library by default.

---

## 0. Rules for you (Sonnet)

1. **Reproduce first, then fix.** Write a failing test, show it fail, fix, show it pass. If you can't reproduce something, mark it "NOT REPRODUCED", keep the test, and don't change the code.
2. **Find every caller before you fix.** Before changing any function named here, grep for every caller and list them in the report. If a function has no callers, say so, delete it in its own commit, and apply the fix to the code that actually runs.
3. **Never say "done" without proof.** Paste the real output of `tool/verify.sh` into `docs/STATUS.md`.
4. **Hard limits.**
   - No internet permission and no network code.
   - No new permissions in `lite`.
   - Old Hive data must load. Schema changes need a migration and a test that uses stored v1 and v2 samples.
   - Anything 2.5 exported must still import.
5. **Translations.** Every new string goes into all 5 languages, in `l10n.dart` / `l10n_more.dart`. The l10n test must check both directions: nothing missing and nothing extra. Every new screen gets an Arabic right-to-left test.
6. **Don't break tests.** Keep existing widget keys (`phoneSearch`, `bulkDelete`, `applyReview` and so on), or update the tests in the same commit and explain why.
7. **Git.** One phase per branch, one commit per task, message format `phase-task: summary`. No refactors outside the task.
8. **Speed numbers.** Run them on the same machine, 3 runs, and report the median.
9. **If the plan and the code disagree,** stop and write it under "Open questions" in STATUS.md.

## Code map (read this before starting)

- **Two workspaces share one base class.** `ContactList` in `state/contact_list.dart` has search, sort, filters and selection. `AppState` is the "Files" library, stored in Hive `library_v1`. `PhoneBook` is the device's contacts, read live through `PhoneSource`. `WorkspaceRoot` switches between them using the `tab` preference, which is limited to −1..1.
- **Every phone write is a `ChangeSet`.** It goes `ChangeSet` → `applyChanges` (`ui/pipeline.dart`) → `Executor` → `Journal`. The journal keeps vCard snapshots and lets you undo.
- **Number logic** is in `models/person.dart` (`Phones`), `domain/number_check.dart`, `domain/international.dart` and `batch/batch_ops.dart`.
- **Search** is `search/fuzzy.dart`. It runs on the UI thread.

## Phase 0: Starting point and checks

- **0.1 Baseline.** Run `flutter pub get && flutter analyze && flutter test`. Record the results, the timings printed by `test/perf_test.dart`, and the release APK size from `flutter build apk --release --split-per-abi` (arm64).
- **0.2 Formatting only.** Commit `0-2: dart format` with no other change. Then check whether `flutter analyze --fatal-infos` passes. If it doesn't, fix only lint issues in commit `0-2b` and list them.
- **0.3 `tool/verify.sh`.** It runs, in order:
  - `dart format --set-exit-if-changed .`
  - `flutter analyze --fatal-infos`
  - `flutter test --exclude-tags perf,golden`
  - `flutter test --tags perf`
  - `flutter test --tags golden`

  Add `dart_test.yaml` that declares the `perf` and `golden` tags. Move the perf test to `test/perf/search_perf_test.dart` with `@Tags(['perf'])`. Until goldens exist, the golden step must pass when it finds no tests. Check how `flutter test` exits when nothing matches, and handle that case. Any failing step must make the script exit with an error.
- **0.4 CI** (`.github/workflows/ci.yml`). Pin Flutter **3.35.4**, the same version as `fdroid/com.contactflow.contacts.yml`. On every push and PR, run `tool/verify.sh`, then `flutter build apk --debug` and `flutter build web`, since the web preview must keep building. Goldens are only created and compared on the Linux runner.
- **0.5 Audit the files I didn't read.** These are `person_row.dart`, `detail.dart`, `phone_detail.dart`, `compose_screen.dart`, `queue_screen.dart`, `reach_ui.dart`, `alias_editor.dart`, `widgets.dart`, `import_issues.dart`, `edit_screen.dart`, `io/numbers.dart`, `search/fold.dart`, `domain/templates.dart` and `domain/sheet_template.dart`. List suspected bugs in the Phase 1 format.
- **0.6 Corpus.** Create `test/fixtures/corpus/` (contents in 1.10).

**Done when:** CI is green on main after the 0.2 commits, and the baseline (tests, timings, APK size) is in STATUS.md.

## Phase 1: Bug fixes (each one: failing test first)

### A. Search

**1.1 Two-digit number search returns nothing.** `FuzzyIndex.search` only treats a query as a number when it has 3 or more digits, and so does the fallback in `_token`. Two related problems:
- The digit-query regex accepts Arabic-Indic digits but not full-width ones (`０-９`), so a full-width query is treated as a name.
- A mixed query like `ahmed 36` returns nothing, because every word has to match and `36` can never match.

*Tests:* `0551234536` is found by `36`, by `٣٦` and by `３６`; `ahmed 36` finds Ahmed when his number ends in 36. The full syntax comes in Phase 3.

### B. File decoding and parsers

**1.2 Wrong text decoding for Arabic and Windows files.** If UTF-8 decoding fails anywhere, `TextDecode.bytes` decodes the whole file as latin1.
*Fix:*
- Count only the **non-ASCII** bytes. If at least 99% of them form valid UTF-8 sequences, decode as UTF-8 and allow bad bytes.
- Otherwise, score Windows-1256 against Windows-1252 by counting letters in the Arabic and Latin ranges.
- Put both decoding tables in the code. No new packages.

Use the same tables for vCard `CHARSET=windows-1256` / `windows-1252`. Today `VCard._decode` only understands latin1 and UTF-8. If a vCard declares a charset we can't decode (GB2312, Big5), return an `ImportIssue` with a clear message instead of garbled text.
*Fixtures:* `cp1256_ar.csv` (mostly digits with short Arabic names, the case that defeats a whole-file count), `cp1252_fr.csv`, `utf8_one_bad_byte.csv`, `vcard21_cp1256.vcf`.

**1.3 Excel files with namespace prefixes come up empty.**
- Make every pattern accept an optional prefix: `<x:row>`, `<x:c>`, `<x:v>`, and also `<x:si>` and `<x:t>` in `sharedStrings`, which today's `_texts` would miss.
- Handle self-closing `<row .../>`.
- When the first sheet has no phone or email column, choose the first sheet that has one, and tell the user which sheet was used.
- *New, lost leading zeros:* when a phone cell is stored as a number, read the cell's style from `styles.xml`. If it has a zero-padded custom format (like `0000000000`), add the zeros back. If there's no such format, the review screen flags "N numbers may have lost a leading 0".

*Tests:* a prefixed workbook, empty rows, contacts on sheet 2, and a padded number format.

**1.8 Google labels and groups are lost, and some columns map to the wrong field.**
- Add `Col.tags` for `Labels`, `Group Membership`, `Categories`, `Tags`, `تصنيف`, `标签`, `Étiquettes` and `Etiquetas`. Split on `:::` and drop system labels (`* myContacts`, `* starred`).
- *New:* Outlook CSV has a `Title` column for "Mr./Dr.", and `classifyHeader` maps it to `Col.title`. Since the first value wins, the real `Job Title` is thrown away. Treat `Title` as a name prefix when the same file also has `Job Title`.
- *New:* Google's `Organization Title` and `Organization Department` contain the word "organization", so they're classified as company. When the company column is empty, the job title ends up as the company. Map `… Title` to `Col.title` and ignore `Department`.

*Tests:* real Outlook and Google CSV headers from the corpus.

**1.10 Broken-file robustness (all importers).**
*Corpus:*
- Damaged or wrong files: truncated zip; renamed `.xls`, `.pdf` and `.png`; zip bomb; empty file; BOM only.
- Encoding and layout traps: UTF-16 without BOM; old-Mac `\r` line endings; `, "a,b"` with leading spaces; fields spanning several lines.
- vCards: vCard 2.1 quoted-printable Arabic; a vCard with 5 MB of photos.
- Real exports: Samsung, iPhone, Google CSV, Outlook CSV, Google Sheets, LibreOffice, Numbers.
- Size tests: a 1M-line txt; 50k-row CSV and XLSX.

*Requirements:*
- (a) `Codec.decode` never throws.
- (b) Every decode runs in an isolate with a 20 s timeout and can be cancelled. Today `decodeInBackground` skips the isolate under 64 KB, and the paste path calls `Codec.decode` directly on the UI thread.
- (c) Zip reading stops once the unpacked size passes 200 MB, with a specific error.
- (d) A fuzz test: 500 random-byte files plus 500 corrupted copies of real fixtures, with no crash and no hang.
- (e) Every corpus file has a test for either the contact count or the expected `ImportIssue`.

### C. Files coming into the app

**1.4 Large shared files can freeze or crash the app.** `MainActivity.read()` calls `readBytes()` on the main thread before checking the 64 MB limit, and it swallows failures.
*Fix:*
- Check `OpenableColumns.SIZE` first.
- On a background executor, copy the stream in chunks with a hard limit into the app's cache folder.
- Send Dart `{name, path}` or `{name, error: tooLarge|unreadable}`, not raw bytes over the channel.
- Dart reads the file inside the decode isolate and deletes it afterwards.
- Also add a size check to the file picker path in `import_sheet.dart`, which uses `withData: true`.

*Test:* an instrumented test, or a documented manual step with a 100 MB file shared from Drive.

**1.11 New, suspected: shared files are lost depending on which tab is open.** Only `HomeScreen` (the Files tab) calls `Incoming.start()` and listens to the stream.
- If the app opens on the Phone tab, which is the default once contacts permission is granted, nothing is received until the user opens Files.
- Worse: once Files has been opened and closed, the handler stays registered. `_take()` then pushes the files into a broadcast stream nobody is listening to, so they're lost.
- Also, `_receive` calls `popUntil(isFirst)`, which throws away any open screen, including a batch editor with unsaved edits.

*Fix:* move the listener up to `WorkspaceRoot` and buffer files until someone handles them. If there are unsaved changes, ask before replacing the screen.
*Test:* a widget test that shares a file while on the Phone tab, after visiting Files once.

**1.12 New, suspected: reopening from Recents imports the file again.** `configureFlutterEngine` reads `intent` on every cold start. When the app is relaunched from Recents after it was killed, Android delivers the original share intent again. *Fix:* ignore intents that have `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`, and mark an intent as used once it's consumed.

### D. Writing to the phone

**1.5 (retargeted) "Repeat runs never create duplicates" isn't true.** `ExportScreen._toPhone` creates a `CreateChange` for every person without a `phoneId`, with no check against numbers already on the phone. If `DeviceContacts.writeAll` really has no callers, delete it.
*Fix:* before building the ChangeSet, drop people whose phone keys (from 1.7) or lowercased emails already exist in `PhoneBook.people`. Show "N already on this phone" on the review screen, with an option to include them anyway.
*Test:* save the same list (with phone-only and email-only rows) twice, and expect no second creation.

**1.6 (retargeted) Arabic compound names get split wrongly.** The "last word is the surname" rule lives in `PhoneSource._name`, `VCard.splitName` (the vCard `N:` field), `NameParts.of`, `SwapName`, and the `{first}`/`{last}` placeholders of `TemplateName`. So "محمد عبد الله" becomes surname "الله".
*Fix:* add one shared helper, `NameSplit`. For Arabic text, or when the name has no clear first/last structure:
- Phone writes: put the full name in given name only.
- vCard: write `N:;<full>;;;`.
- `SwapName`: skip the contact and report it as skipped.

Also check particles like عبد, أبو, بن, ابن, آل, al-, el- and bin. Latin names are unchanged.
*Tests:* a table of at least 15 names in Arabic, Latin and Chinese, run through every caller.

**1.13 New, suspected and serious: editing a contact may delete fields the app doesn't read.** `PhoneSource._fresh` loads only `_props` (name, phone, email, organization, note, favorite). Then `update(apply(base, p))` writes the whole contact back. The README promises prefixes, phonetic names and departments survive. Nothing promises addresses, birthdays, websites, events, relations or photos, and the journal's vCard backup can't bring them back.
*Check on an emulator:* in the system Contacts app, create a contact with an address, birthday, website and photo. Rename it in Contact Flow. Check that every field is still there. If anything is lost, load all properties before updating, or update only the properties that changed. Add an instrumented test.

**1.14 New, suspected: groups with the same name in different accounts get mixed up.** `_loadGroups` uses `putIfAbsent(name)`, so "Family" (on the device) and "Family" (in Google) become one group ID, and `_syncGroups` can add a Google contact to the device group. It also runs one `getAll` query per group, and that happens on every resume.
*Fix:* key groups by `(account, name)` and read membership in one query. Filter out system and read-only groups ("My Contacts", "Starred in Android", Samsung ICE). Phase 4c needs this.

### E. Numbers

**1.7 Number matching uses the last 9 digits.** This is the riskiest change, so it gets its own branch and merge.

*Design:*
- Add `phone_numbers_parser` (pure Dart, MIT). Put all number identity in one new place, `lib/phone/phone_key.dart`, and replace the 7 copies listed at the top (show the grep).
- Each number gets a **key set**: `e164` when it can be parsed, plus `nsn` (the national significant number).
  - Two numbers match if their `e164` values are equal.
  - They also match if at least one of them couldn't be parsed and their `nsn` values are equal.
  - Two different country codes never match.
- **No regressions:** every pair the old key matched in the existing fixtures must still match, unless the two numbers have provably different country codes. Write a test that lists every pair that changed.

*Default region:*
- Use the SIM country (`TelephonyManager.getSimCountryIso()`, no permission needed, through a small channel that both builds have). If there's no SIM, use the locale. The user can change it in Settings.
- **Migrate** the existing `country` preference from a calling code to a region. `+966` becomes SA. Codes shared by several countries (`+1`, `+7`, `+44`) open a picker.
- `Reach`, `InternationalNumber`, `AddCountryCode` and the "no country code" filter must all use the region.

*Speed:* cache parsed results by raw string. Build the index in an isolate. Record APK size before and after. Budget: +2 MB at most.

*Tests:* at least 30 cases covering SA, AE, BH (8-digit, with and without `+973`), KW, QA, EG, JO, CN, FR, ES, US and UK. Also extensions (`x12`, `#12`), Arabic-Indic digits and `00` prefixes. Run all the domain tests: matcher, merger, sync, number_check.

**1.15 New: the batch number tools break real numbers.**
- `RemoveCountryCode` always adds a 0 (`addTrunkZero` defaults to true, and the dialog has no toggle). So `+34 612…` becomes `0612…`, `+1 415…` becomes `0415…`, `+39 06…` becomes `006…`, and Chinese mobiles `+86 138…` become `0138…`. Spanish and Chinese users are directly affected.
- `AddCountryCode` keeps a stray trunk 0 (`966 050…` becomes `+966050…`) and merges extension digits into the number.
- `FormatNumbers(spaced)` groups digits from the end, so `+966501234567` becomes `+96 650 123 4567`.

*Fix:* after 1.7, all three use the parser: national format for "remove", E.164 for "add", international format for "spaced". Numbers that can't be parsed are left alone and counted in the preview as "N unchanged (couldn't read)".

### F. Storage and privacy

**1.9 (expanded) Data can disappear without a trace.**
- `LibraryStore.load()` and `migrate()` skip rows they can't read. So does `Journal.load()`.
- If `_store.open()` throws, `AppState.init` catches it and continues with `_b == null`. From then on, every `putAll` silently does nothing: the user imports contacts, sees them, and loses them on restart.

*Fix:*
- Move broken rows to `quarantine_v1`. Settings shows "N items couldn't be read" and can export them as raw JSON.
- If the store fails to open, show a blocking error, and make writes throw instead of doing nothing.

*Test:* extend `migration_test.dart`. Its corrupt row must now land in quarantine. Add a stored v2 sample.

**1.16 New: decide on cloud backup** (see the decision above). Add `android:allowBackup` / `dataExtractionRules` excluding the Hive files, per your answer. Document it in the README's privacy section.

### G. State and speed

**1.17 New, suspected: freezes and slow lists during search.**
- (a) While a search is active, `replacePeople` → `resort()` → `_runSearch()` rebuilds the whole index on the UI thread (about 0.5 s at 10k contacts). That happens on every `onResume` and every contacts-database change, because `PhoneBook.refresh(quiet:true)` runs each time.
- (b) `hitFor()` scans every result for each row it draws, which is O(n²) when scrolling results. Use a map.
- (c) `TextOps.title` creates a new RegExp for every character.

*Test:* a perf test that refreshes 10k contacts while searching, with a cap on UI-thread time.

**1.18 New: library duplicates and the dedupe button.** `AppState.plan` and `dedupe` only match by phone, so re-importing email-only rows always creates duplicates. The Settings → Dedupe button changes data right away, with no preview and no undo. *Fix:* also match by lowercased email. Make dedupe show a preview first and offer undo in a snackbar.

**1.19 New: import review screen bugs.** If the user skips duplicates while "merge" is off and then turns merge back on, `count` subtracts those skipped duplicates and shows the wrong number. If `commit` throws, `_busy` never resets and the spinner never stops. Rows past 400 can't be skipped. Fix all three. Phase 2.4 rebuilds this screen anyway.

**1.20 New: exports drop fields.** Normal vCard export leaves out `TITLE` and `CATEGORIES` (they're only written in "lossless" mode). CSV, XLSX and JSON have no job title or groups. *Fix:* add `Job Title` and `Groups` columns (off by default for CSV) and always write `TITLE`. Phase 4's round-trip tests depend on this.

**Phase 1 done when:** every item is marked FIXED or NOT REPRODUCED with its test, 1.7 is merged on its own, the corpus is complete, and CI is green.

## Phase 2: Modern UI (look and layout only, no behaviour changes)

- **2.1 Design tokens.**
  - Rename the `Type` class in `theme.dart` to `AppText`. Today it hides Dart's built-in `Type`.
  - Put colours, spacing (4/8 scale), radius, text styles and animation timings in one file.
  - Material 3, with dynamic colour on Android 12+ through `dynamic_color`. The custom `Palette` (paper, ink, accent and so on) has to be derived from the dynamic scheme too, otherwise half the UI keeps the old colours.
  - Extend `palette_test.dart` to check contrast for 6 sample seed colours in light and dark.
  - The brand colour (#E8664A) stays the default.
- **2.2 Navigation.**
  - Bottom bar: Contacts (today's Phone workspace) · Calls (full build only) · Tags · Files (today's library).
  - Migrate the `tab` preference, which is limited to −1..1 today, and test it.
  - Large title that collapses on scroll. `SearchAnchor` with filter chips under it, keeping the `phoneSearch` key.
- **2.3 Lists.**
  - Swipe actions that can be turned off. In Arabic they flip with the reading direction, so the gesture means "from the start edge", not "from the left".
  - Long-press then drag to select a range. A sticky bar for bulk actions.
  - Skeleton placeholders while loading. Empty states that suggest a next step.
  - If tag chips make rows taller, update `RowMetrics` and the A–Z scroller offsets.
- **2.4 Import review screen.** Group into New / Duplicates / Skipped / Problems. Make every row reachable (no 400 cap); use paging if needed. Expanding a row shows the original line from the file.
- **2.5 Quality checks.**
  - Goldens for each main screen in 8 setups: light/dark × English LTR/Arabic RTL × text scale 1.0/2.0, at 360×800, plus one 320 dp-wide phone.
  - **Load bundled Noto Sans Arabic and Noto Sans SC test fonts.** The app only bundles Manrope and Instrument, so Arabic and Chinese would show as boxes in tests.
  - Generate goldens only on Linux CI.
  - Tests fail on any overflow. Tap targets are at least 48 dp. Use `meetsGuideline` checks.
- **2.6 New: Arabic plurals.** `L.n` only knows "one" and "many", but Arabic has six plural forms, so "3 selected" and "11 contacts" come out wrong. Add the Arabic forms (zero, one, two, few, many, other) to the plural helper. Change the l10n test so it stops skipping Arabic `_one` keys and checks the forms instead.

**Done when:** you have approved the goldens and reviewed the screenshots in `docs/screens/`.

## Phase 3: Smart number search

Query rules (also shown in a "?" help sheet):

| Typed | Meaning |
|---|---|
| `36` | Anywhere, ranked: exact > ends with > starts with > contains. Chips switch the mode. |
| `*36` / `02*` / `02*36` / `*55*` | Ends with / starts with / both / contains |
| `05?1*` | `?` = exactly one digit |
| `02* #work` | Space = AND. `#` = tag |
| `*36, *37` | Comma = OR |

Details:
- **Parse before any other processing.** Today's code strips `*`, `#` and `?`.
- **Also accept the Arabic and Chinese versions of these characters:** Arabic `؟` (U+061F) and `،` (U+060C), full-width `？ ＊ ＃ ，`, plus Arabic-Indic and full-width digits. An Arabic keyboard doesn't type ASCII `?` or `,`.
- **"Starts with" checks three forms:** the number as saved, its national form, and its E.164 digits. So `05*` finds `+9665…`, and `9665*` finds `05…`.
- Ignore spaces, dashes and brackets. Extensions are never matched.
- **Chips for digit-only input:** "Ends with 36 · Starts with 36 · Contains 36". Highlight the matched digits. Keep recent searches. Add "Save as smart filter".
- **Works in both workspaces:** build it into `ContactList`, so Contacts and Files both get it.
- **Separate parser:** `NumberPattern` plus a precomputed per-number index (saved, national, E.164 and reversed digits). Patterns don't go through the fuzzy scorer.
- **Tests:** at least 40 parser cases (including `**`, `*`, `?`, `#`, `،`, `؟`), matching tests, and mixed text-and-number queries.
- **Speed targets:**
  - 10k contacts / 20k numbers: p95 under 8 ms.
  - Text search no slower than baseline +10%.
  - Each keystroke under 16 ms of UI-thread time. Move fuzzy search to an isolate or add a 2-gram pre-filter.
  - Measure in `test/perf/`.

## Phase 4: Tags

**Model.**
- `Tag {id, name, colour, created}`.
- `NumberTag {key, raw, region, tagId, note?}` in Hive `tags_v1`, with a migration and a test.
- **Key stability:** `key` is the E.164 form when the number parses. Otherwise it's `nsn` plus the region used. If the user later changes the default region, re-key the unparsed entries and show "N tags moved". Never orphan a tag silently.

**Behaviour:**
- Tags attach to numbers, so they work for unsaved numbers. A contact shows the union of its numbers' tags, in both workspaces.
- **Tags live only in the app, not on the phone.** Add tags to JSON export, and add a "Tags backup" export/import in Settings. Say clearly in the UI that reinstalling without a backup loses tags.
- **Tags tab:**
  - Each tag with a count. Tapping a tag shows "Saved contacts" and "Not in contacts".
  - Rename, merge, recolour and delete, each with undo.
- **Assigning tags.**
  - From any selection or a detail page.
  - A quick picker where typing a new name creates the tag.
  - Batch tagging from search results, so "all `*36`" can be tagged in one go.
- **Search:** `#tag` or tag chips.
- **Export.**
  - Filter by tag.
  - `CATEGORIES` in vCard, a `Tags` column in CSV/XLSX, `tags` in JSON.
  - Round-trip tests for every format.
- **Import tags from:**
  - (a) Google `Labels` (from 1.8)
  - (b) vCard `CATEGORIES`
  - (c) phone groups, using the account-aware, system-group-free list from 1.14: show member counts, let the user pick, preview, then apply
  - (d) a Tags column in the template
- **Samsung Phone tags (2 hours maximum):** check on a real Galaxy phone whether call tags show up in groups, in the call log's `CACHED_NAME`, or in Samsung's `.vcf` export. Record the result. If they don't show up (expected), the help text says honestly that tagging unsaved callers is a one-tap action in the Calls tab.
- **Later, not in this release:** mirror a tag into a phone group.

## Phase 5: Call history (`full` build only)

- **5.1 Build setup.**
  - Product flavors `lite` and `full`. `full` gets `applicationIdSuffix = ".full"` and its own name and icon badge.
  - Only `src/full/AndroidManifest.xml` adds `READ_CALL_LOG`.
  - The Kotlin call-log code lives in `src/full/kotlin/`, with an empty stub in `src/lite/kotlin/`, so the lite APK contains no call-log code at all.
  - On the Dart side, check `const bool.fromEnvironment('CALLS')`. **A flavor doesn't set the dart-define by itself.** Add a startup check: the native side reports its flavor over a channel, and the app shows an error if the two don't match. Build commands:
    - `flutter build apk --flavor lite`
    - `flutter build apk --flavor full --dart-define=CALLS=true`
  - Update the README, the fastlane listings, and `fdroid/` (two recipes with two output paths, `app-lite-release.apk` and `app-full-release.apk`).
  - Add the "Move my data" export and import.
  - *Verify:* run `aapt dump permissions` on both APKs in CI and fail if lite contains `READ_CALL_LOG`.
- **5.2 Native reader.**
  - Read `CallLog.Calls` (NUMBER, DATE, DURATION, TYPE, CACHED_NAME, NUMBER_PRESENTATION, PHONE_ACCOUNT_ID) in pages of 2,000, newest first, on a background executor.
  - Ask for the permission only when the user opens the Calls tab, after an explanation screen.
  - *Device check:* sideloaded installs on Android 13, 14, 15 and 16. Record whether the "restricted settings" blocking applies.
- **5.3 "Unsaved callers" screen.**
  - Group calls by number key and leave out numbers already in contacts.
  - Each row: number, call count, incoming/outgoing/missed icons, last call, total talk time, tags.
  - Hide private, unknown and short-code numbers (fewer than 6 digits) by default, with a toggle.
- **5.4 Including and excluding, the core of this feature.**
  - Everything starts unselected.
  - Chips: *Called 2+ times*, *Talked > 30 s*, *Last 30 days*, *Missed only*, *Outgoing only*, plus any Phase 3 pattern. Then "Select all shown" / "Invert".
  - Swipe from the start edge to include, from the end edge to exclude (mirrored in Arabic). Long-press-drag selects a range.
  - "Never suggest" adds the number to `ignore_v1`, which can be managed and undone in Settings.
  - Live counter: "12 selected · 3 excluded", with Arabic plurals from 2.6.
- **5.5 Naming and saving.**
  - One editable table with a name per row, pre-filled from a template (`{tag} {last4}`, `Caller {n}`, or blank). Reuse the batch rename tools.
  - The user picks tags and the target account.
  - **Check again right before saving:** re-read the contacts and drop numbers that were saved in the meantime. Use the 1.5 logic.
  - Save through `ChangeSet` with undo.
  - "Tag only, don't save" for numbers the user wants to keep out of contacts.
  - Measure the time for 500 creates. The executor writes one contact at a time, so the progress dialog has to stay accurate.
- **5.6 Speed targets.** Group 20k fake calls in under 500 ms on desktop. Show the first page in under 300 ms on a mid-range phone, and record the phone model.

## Phase 6: Release

- Bump to 3.0.0 in both `pubspec.yaml` and the `appVersion` constant in `settings_sheet.dart`. `version_test.dart` must still pass.
- Write a CHANGELOG and "What's new" in the README (both builds, tags, search syntax, the backup decision).
- Update the performance table and add an APK size table for both builds.
- Update the store screenshots.
- Write `docs/QA.md` (one line per feature, each marked pass or fail) and run it on a real phone for both builds.

## Report template (add to STATUS.md after every task)

```
Task: 1.3  Status: FIXED | NOT REPRODUCED | BLOCKED
Callers checked: (grep output)
Failing test: test/io/xlsx_prefix_test.dart (output before the fix pasted)
Change: files + one-line summary
verify.sh: (full output pasted)
Speed / APK size: before → after (if relevant)
Risks / follow-ups:
```

---

Three things before you hand this over:

1. **Answer the backup question** (task 1.16). I set "leave contacts out of Google backup" as the default, but it's your decision.
2. **Do 1.13 first in Phase 1.** If editing a contact really deletes addresses or birthdays, current users are losing data today, and the undo backup can't bring it back. Everything else in Phase 1 is less urgent.
3. **Merge 1.7 on its own before Phase 3**, as before. The "no regressions" rule is what makes it safe: without it, numbers saved without a country code could quietly stop being detected as duplicates.

Google Play still only takes the `lite` build.

All the new items (1.11 to 1.20) come from reading the code, not from running it. That's why each one has to be proven with a failing test first.