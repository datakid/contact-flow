# Changelog

## 3.0.0

- Two builds. Lite never asks for the call log. Full adds the Calls tab, which groups the numbers you called but never saved and lets you save, tag or ignore them.
- Search by number pattern: `*36` ends with 36, `02*` starts with 02, `?` is one digit, a comma means either, `#family` finds a tag or group, and chips switch plain digits between anywhere, ends with, starts with and contains.
- Tags on numbers (not contacts) with a Tags screen, tag chips in the contact detail, a tag filter, tags in exports and a backup in Move my data.
- Number matching is country-aware. Two explicit numbers with different country codes no longer match; numbers saved without a country code still match by their national part. A country is detected from the SIM, then the phone language, and can be changed in Settings.
- Import fixes: Windows-1256 and Windows-1252 text, quoted-printable vCards with a charset, Excel files with namespace prefixes, files whose contacts are on a later sheet, zero-padded number formats, quoted CSV fields after spaces, old Mac line endings, size and time limits, and clear messages for damaged or unsupported files.
- Contacts that cannot be read are kept in a quarantine you can export instead of being dropped; a library that fails to open blocks the app instead of ignoring your changes.
- Dedupe shows a preview and can be undone. Re-importing a file matches by email as well as number. Saving contacts from a file skips the ones already on the phone.
- Arabic names and names with particles such as bin or al- are no longer split into a guessed first and last name.
- Exports include job title and groups; vCard always writes the job title.
- Arabic plurals follow all six forms for counts.
- Contacts and tags are left out of Google Drive backup. Use Move my data to carry them to a new phone.

## 2.5.0

See the README for earlier releases.
