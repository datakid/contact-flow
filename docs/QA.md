# QA checklist for 3.0.0

Run each line on a real phone for both builds (lite and full) and replace NOT RUN with PASS or FAIL. Use tool/verify.sh and tool/check_permissions.sh first.

| Area | Check | Lite | Full |
| --- | --- | --- | --- |
| Install | Lite installs as Contact Flow, Full as Contact Flow Full, side by side | NOT RUN | NOT RUN |
| Permissions | Lite never shows a call log prompt; Full asks only when the Calls tab opens | NOT RUN | NOT RUN |
| Startup | No edition error screen; library opens | NOT RUN | NOT RUN |
| Region | A country is detected from the SIM or the language; changing it in Settings shows "N tags moved" when numbers move | NOT RUN | NOT RUN |
| Search | `*36`, `02*`, `*55*`, `05?1*`, `*36, *37`, `ahmed *36`, `#tag`, Arabic digits | NOT RUN | NOT RUN |
| Search | Digit chips: anywhere, ends with, starts with, contains | NOT RUN | NOT RUN |
| Search | Help button explains the syntax | NOT RUN | NOT RUN |
| Phone | Edit a contact that has addresses, birthdays, websites and a photo; nothing is lost (task 1.13) | NOT RUN | NOT RUN |
| Phone | Groups with the same name in two accounts stay separate (task 1.14) | NOT RUN | NOT RUN |
| Phone | Save the same list twice: the second time says how many are already on the phone | NOT RUN | NOT RUN |
| Phone | Names such as bin or al- compounds and Arabic names are not split | NOT RUN | NOT RUN |
| Tags | Create, rename, recolour, merge, delete and undo | NOT RUN | NOT RUN |
| Tags | Put a tag on a number in contact detail; remove it; filter the list by it | NOT RUN | NOT RUN |
| Tags | Same number in a different format shows the same tags | NOT RUN | NOT RUN |
| Import | Windows-1256 CSV, Windows-1252 CSV, vCard 2.1 quoted-printable, Excel with prefixed XML, later-sheet contacts, leading zeros | NOT RUN | NOT RUN |
| Import | Damaged file, zip bomb, renamed PDF and image give a clear message and no freeze | NOT RUN | NOT RUN |
| Import | Share a large file into the app from another app | NOT RUN | NOT RUN |
| Import | Reopen from Recents after a share does not offer the file again | NOT RUN | NOT RUN |
| Dedupe | Preview shows the count, merge works, undo restores both contacts | NOT RUN | NOT RUN |
| Export | Job title and groups columns; tags column; vCard has TITLE and CATEGORIES | NOT RUN | NOT RUN |
| Backup | Contacts and tags are absent after a Google backup and restore | NOT RUN | NOT RUN |
| Move my data | Export and import on a second phone restores contacts, tags and ignored numbers | NOT RUN | NOT RUN |
| Calls | Tab is absent in Lite | NOT RUN | n/a |
| Calls | Permission screen, loading counter, grouping, filters | n/a | NOT RUN |
| Calls | Select, exclude, never suggest with undo, ignored numbers screen | n/a | NOT RUN |
| Calls | Save with a template, tag only, numbers saved meanwhile are skipped | n/a | NOT RUN |
| Languages | English, Arabic (RTL), Chinese, Spanish, French: new strings and Arabic plurals | NOT RUN | NOT RUN |
| Layout | 300 px wide screen and large text show no overflow on the new screens | NOT RUN | NOT RUN |

## Measurements to record

| Measure | Lite | Full | Phone model |
| --- | --- | --- | --- |
| Release APK size (arm64) | NOT MEASURED | NOT MEASURED | |
| Size before the number parser was added (2.5.0) | NOT MEASURED | | |
| First search with 10,000 contacts | NOT MEASURED | NOT MEASURED | |
| First page of the Calls tab with 20,000 calls | | NOT MEASURED | |
| 500 contacts created from calls | | NOT MEASURED | |
