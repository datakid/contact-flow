<p align="center">
  <img src="web/icons/Icon-192.png" width="96" alt="Contact Flow">
</p>

<h1 align="center">Contact Flow</h1>

<p align="center"><em>Your contacts, moved beautifully.</em></p>

<p align="center">
Batch import and export phone contacts in every common format, with fuzzy search that understands English, Arabic and Chinese.
</p>

---

## What's new in 2.1.0

- **Phone workspace** — search, sort, filters (account, starred, group, no number, no name), A–Z scroller, detail, create/edit, bulk star/group/delete, share vCard
- **Safe changes** — every phone write is a reviewed ChangeSet; affected contacts are backed up as vCard first; undo from the snackbar or Settings → History (30 entries / 30 days)
- **Sync from a spreadsheet** — export with `contact_id`, edit, import → "Update contacts on this phone"; matching by contact_id → number → exact name; Fill empty / Overwrite / Add numbers; conflicts never guessed
- **Duplicates & merge** — by shared number or same name, choose who to keep
- **Reach** — Call, SMS, WhatsApp, Signal, copy numbers; personalised one-by-one message queue that survives restarts; group SMS with warnings. The app never sends anything itself.
- Permissions: `READ_CONTACTS` and `WRITE_CONTACTS` only. No internet.

## Formats

| Format | Import | Export | Best for |
|---|:-:|:-:|---|
| `.csv` | ✓ | ✓ | Spreadsheets, bulk lists |
| `.vcf` | ✓ | ✓ | Contacts apps (vCard 2.1 / 3.0 / 4.0) |
| `.xlsx` | ✓ | ✓ | Excel |
| `.txt` | ✓ | ✓ | Plain lists of numbers |
| `.json` | ✓ | ✓ | Apps and APIs |
| `.numbers` | ✓ | ✓* | iPhone and Mac |

\* Exported as a spreadsheet that Numbers opens directly. Apple's native format is undocumented.

## Features

- **Batch edit in a table**: edit names, numbers and companies inline; bulk operations (find & replace, prefix/suffix, numbered rename patterns, change case, swap first/last, clean up names, add/remove country code, change prefix, reformat, remove repeated numbers, set label, set company, add note), each with a before/after preview and undo

- **Whole address book in one tap** on Android, or many files at once, or pasted text
- **Open with Contact Flow**: share or open a `.vcf`, `.csv`, `.xlsx`, `.numbers` or `.json` file from WhatsApp, email or Files and it goes straight to review
- **Smart column detection**: finds name, phone, email, company and note columns from headers in English, Arabic, Chinese, French, Spanish and more, or from the cell contents when there is no header
- **Review before import**: new contacts and duplicates shown separately, with duplicates merged by number
- **Export all, a search result, or a hand-picked selection**: choose the number style (as saved, international, digits only) and the fields to include, with a live preview
- **Save, share, or write back** into the phone's address book, skipping numbers already on the phone so repeat runs never create duplicates
- **Fuzzy search**
  - Tolerates typos: `jonatan` → Jonathan
  - Ignores accents: `jose` → José
  - Arabic, ignoring vowel marks and letter variants: `احمد` → أحمد
  - Chinese by pinyin or initials: `wang` → 王伟, `lxl` → 李小龙
  - Across scripts: `mohamed` → محمد
  - Partial numbers, including Arabic-Indic digits
- **Five languages**: English, العربية (right-to-left), 中文, Español, Français
- **Light and dark themes**, following the system by default
- **Private**: no internet permission at all, no network calls, no analytics, no ads

## Performance

Measured on a desktop runner with 10,000 contacts:

| | Time |
|---|---|
| Import (any format) | ~0.3–0.6 s |
| Export (any format) | ~0.02–0.4 s |
| Search index build | ~0.5 s |
| Each search | ~10–130 ms |

Import and export run in a background isolate, so the UI stays responsive.

## Build

Requires Flutter 3.35 / Dart 3.9.

```bash
flutter pub get
flutter test
flutter run                              # device
flutter build apk --release --split-per-abi
flutter build web --release              # preview, sample data only
```

For a signed Android build, add `android/key.properties`:

```properties
storePassword=…
keyPassword=…
keyAlias=release
storeFile=../release-key.jks
```

Without it, release builds fall back to debug signing.

## Project layout

```
lib/
  batch/     pure batch operations (rename, numbers, company, notes)
  io/        csv · vcard · xlsx · numbers · txt · json codecs, background jobs
  search/    text folding and the fuzzy index
  services/  device contacts, local store, save and share
  state/     app state
  ui/        screens and design system
test/        format round-trips, real .numbers files, search, performance,
             batch operations, batch editor and full-app smoke tests
fastlane/    store listing (en, ar) used by F-Droid / IzzyOnDroid
fdroid/      draft F-Droid build recipe
```

## Permissions

`READ_CONTACTS` and `WRITE_CONTACTS` (Android), requested only when you import from or save to the phone.

## Install

Releases are signed APKs. Use `app-release.apk` if unsure, or
`app-arm64-v8a-release.apk` for most phones from 2017 onward.

## License

Code: MIT, see `LICENSE`.
Fonts: Manrope and Instrument Serif, SIL Open Font License 1.1, see
`assets/fonts/OFL-*.txt`. All licenses are also listed in the app under
Settings → Open-source licenses.
