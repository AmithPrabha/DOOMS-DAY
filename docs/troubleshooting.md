# Troubleshooting

## Empty production library

Cause: no approved starter content. Check review_status and translation_review in
the content files. Production intentionally filters draft material. Use the
development build for review; do not bypass the publication gate to ship drafts.

## Search misses a topic

Check selected language and whether the pack is installed. Inspect the article's
title, aliases and keywords. Run the alias test in Test Center or
`flutter test test/database_test.dart`. AppDatabase.installArticles updates both
the article table and FTS index in one transaction.

## Blank map

Check that a map pack is installed, not merely partially downloaded. Verify files
in Downloads. Inspect style source names, archive schema, glyph paths and sprites.
All references must resolve locally. Read the map's coverage bounds before
assuming a blank area is a rendering bug. Native rendering needs device evidence.

## Download fails

Read the displayed reason: network preference, HTTPS response, budget, device free
space, checksum, content review, or archive structure. Partial bytes remain for
resumption. A checksum failure deletes the invalid partial file. Do not mark a
pack installed by editing its database row.

## Update leaves an old directory

Old versions are retained intentionally and counted in disk usage. The active
directory is in the packs table. Preserve it. Use the documented recovery process
to reactivate a previous validated package; do not delete the database.

## Text clips or a script is missing

Check the selected font family in FieldkitApp and font assets in pubspec.yaml.
Run the multilingual widget test. Check Directionality and avoid fixed text
heights. A font can be present without having every glyph; inspect real devices.

## Permission denied or compass unavailable

These are supported states. Handbook reading does not require device permissions.
Location is requested by NavigationService.locate after the user's action. A
missing magnetometer cannot be repaired in software.

## How to change a screen

Locate its feature in the Features tab, edit the corresponding widget, run its
tests, test large text and error states, then regenerate this guide.

## How to change search

Edit AppDatabase.articles or article aliases. Keep query parameters and quoted FTS
tokens. Add a regression case for the search that previously failed.

## How to add a feature

Add a module with a provider boundary, register the feature and acceptance cases,
document its inputs/outputs and permissions, and update store disclosures if its
data flow changes. Keep feature-specific test fixtures inside development code.

## Guided maintenance walkthroughs

| Task | Locate and change | Verify |
|---|---|---|
| Change a screen | Find its F-number in Features. Open its source path. Edit the widget and add new labels to each assets/i18n locale. Keep controls in scrollable layouts at large text. | Run test/ui_test.dart; preview light/dark and Arabic at 200%; inspect screenshots. |
| Add a topic | Add a stable category key to categoryNames in lib/features/handbook.dart and a category label in each locale. Add an article with that category, region, audience, sources and license in assets/content/essential.json. | Run tools/check.py and search the topic in development. Obtain review before publication. |
| Fix a translation | Edit the matching assets/i18n/code.json label or the article with matching ID/language. Return edited articles to draft and remove their old review fingerprint. | Validate key parity, inspect text direction/glyphs, obtain a new translation review and fingerprint. |
| Add a language | Add the locale to languages in lib/core/models.dart, check Material localization support in lib/app.dart, add offline font configuration and translation files. Update the validator language list and test registry. | Run text layouts and content validation; check real devices offline; complete translation review. |
| Change a search rule | Edit AppDatabase.articles in lib/data/database.dart. Keep bound SQL parameters and escaped FTS tokens. Add a query/expected-ID fixture to test/database_test.dart. | Run the database tests and test the exact query in Test Center. Reinstall content if indexing rules changed. |
| Diagnose a missing map | Downloads → Verify files. Check active packs.path in SQLite, manifest hashes, coverage bounds, style source names and local glyph/sprite files. Inspect MapScreen._select in lib/features/maps.dart. | Reinstall a corrected immutable pack; cold restart in airplane mode, pan and zoom across coverage on both platforms. |
| Recover a failed download | Check Downloads message, Wi-Fi setting, budget and free space. PackService.download in lib/services/packs.dart retains a hash-specific .part file. Retry the same catalog version to resume. | Confirm final hash and installed version. If corrupt, publish a new version; old active content must still open. |

## Diagnostic lookup

| Symptom | Likely cause | Source and diagnostic | Fix | Verification |
|---|---|---|---|---|
| UI works but preview shows no heading | Controlled missing-sensor scenario | lib/development/fixtures.dart; inspect scenario | Choose normal fixture or probe the real compass in Diagnostics | T24 plus real-device T15 |
| Install rejects reviewed text | Content changed after review | PackService.reviewDigest; compare reviewed_content_sha256 | Obtain renewed review for the actual version; do not copy an old hash | T17 |
| Build evidence rejected | Source fingerprint differs or BUILD_ID missing | tools/check.py build_id; Test Center build label | Build using tools/flutter.py and rerun tests for that source | Import matching registry/results.json |
| Optional storage remains after updating | Prior version retained | PackService.usedBytes / clearUnused | Use Downloads cleanup after confirming the active version works | T11; active pack still verifies |
| Android package excludes non-GPS devices | Merged manifest inferred required hardware | Inspect aapt dump badging output and AndroidManifest.xml | Declare location, network location and GPS optional | Rebuild and inspect uses-feature entries |
