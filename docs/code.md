# Code and data

## Important entrypoints and functions

| Symbol | Responsibility | Inputs and outputs | Side effects and failure handling |
|---|---|---|---|
| bootstrap | Opens storage and starts providers | Development flag, optional test-screen builder | Seeds reviewed/draft content by flavor; displays recoverable startup error |
| AppDatabase.installArticles | Replaces one pack's content atomically | Pack ID and article list → completion | Transaction; rejects identifiers owned by another pack |
| AppDatabase.articles | Local search and filters | Locale, query, category, level, bookmark flag → articles | Reads SQLite only; parameterized FTS |
| AppDatabase.removePack | Removes optional content | Pack ID → completion | Keeps bookmarks; rejects essential removal |
| PreferencesController.update | Updates UI immediately and serializes persistence | AppPreferences → completion | Latest failed write restores the last committed preferences |
| PackService.download | Downloads and validates a pack | Manifest, budget, cancellation, network predicate → completion | Resumable partial file; errors leave prior version active |
| PackService.installVerified | Validates and activates an archive | Pack and file → completion | Staging directory plus database transaction; rejects unsafe files |
| PackService.verifyInstalled | Checks persisted resources | Pack directory → boolean | Reads all declared resource hashes |
| NavigationService.locate | Requests a foreground GPS fix | No location input → Position | Explicit permission handling and timeout |
| NavigationService.distance / bearing | Coordinate math | Two coordinates → meters / degrees | Pure functions |
| openArticle | Opens selected language or identified English fallback | Article ID → reader route | Missing content gives an explicit message |

Source locations are in the Features tab. Function names can be searched in the
editor. Database code lives in [database.dart](../lib/data/database.dart), pack code
in [packs.dart](../lib/services/packs.dart), and app providers in
[providers.dart](../lib/core/providers.dart).

## Callers and verification

| Symbol | Callers | Tests |
|---|---|---|
| bootstrap | main.dart and main_development.dart | T01 / T02; integration_test/offline_test.dart; native builds |
| AppDatabase.installArticles | bootstrap and PackService.installVerified | T01, T10, T11 |
| AppDatabase.articles / rankedArticles | KnowledgeRepository and Test Center | T03, T05, T27 |
| AppDatabase.toggleBookmark / bookmarks | ArticleTile, ArticleScreen, bookmarksProvider | T04 |
| AppDatabase.savePlace / places / deletePlace | MapScreen | T16; device scenario T15 |
| AppDatabase.preferences / savePreferences | bootstrap and PreferencesController | T07, T21 |
| AppDatabase.migration | Drift database opening | T21 |
| PreferencesController.update | SettingsScreen and QuickHeader | T05, T07, T25 |
| PackService.catalog / download | DownloadsScreen | T08, T09, T12, T24 |
| PackService.installVerified | PackService.download | T10, T11, T17 |
| PackService.validateArticle / reviewDigest | bootstrap and installVerified | T17 |
| PackService.verifyInstalled | MapScreen and DownloadsScreen | T14 |
| PackService.clearUnused / remove | DownloadsScreen | T04, T11 |
| PackService.diskBytes / usedBytes | DownloadsScreen, Test Center, download | T12; native device check |
| NavigationService.locate / compass | MapScreen through navigationProvider | T15, T24 |
| NavigationService.distance / bearing | MapScreen saved-place display | T16 |
| openArticle | EmergencyScreen and LibraryScreen | T01, T03; integration test |
| FixtureNavigation / FixturePacks | Development preview only | T24; production graph T18 |
| check.validate_content / validate_registry | check.py, publish_pack.py, release.py | T17, T19 |
| release.release_errors | release.py and store-build wrapper | T20 |
| docs.generate | docs.py and run_tests.py | T19 |

`validateArticle` throws FormatException for invalid structure and StateError for
missing review. `reviewDigest` is a pure SHA-256 function over canonical article
JSON excluding review metadata. `clearUnused` removes only inactive version
directories and partial files inside the pack root, returning recovered bytes;
it refuses to run during a download. `catalog` performs an explicit HTTPS fetch,
or reads the bundled empty catalog when no host is configured. `diskBytes`
queries the native storage channel; `usedBytes` scans optional pack storage and counts saved Wikipedia JSON bytes.

`savePlace` validates finite coordinates and writes a user-owned record.
`toggleBookmark` writes independently of replaceable content.
`FixtureNavigation` returns controlled sensor absence/denial without calling
native APIs; `FixturePacks` can fail catalog retrieval without touching installed
content. Fixtures are reachable only through the development entrypoint.

## SQLite schema

`articles` contains a JSON body plus language, ID, category, level and pack index.
`article_search` is the FTS5 index. `bookmarks`, `preferences`, `places`, and
`checklist` contain user-owned data. `packs` records the active immutable directory,
version, type, installed size and archive hash.

Schema version 3 adds `archives` and `download_jobs` metadata tables. Version 2 added checklist storage. Migrations are explicit in
AppDatabase.migration and tested against version-one and version-two fixtures. Never delete a
database to hide a migration failure.

## Pack contract

A catalog has schema_version 1 and a packs array. Each pack has id, title, version,
language, kind (`content` or `map`), URL, SHA-256, exact compressed and installed byte
counts, and description. HTTPS is required; redirects are rejected.

An archive contains `manifest.json` and either `articles.json` plus illustrations,
or `map.pmtiles`, `style.json`, and any local glyph/sprite assets. The manifest
contains identity, version, kind, and hashes of its data files. Paths are relative;
symlinks, executable files, traversal and duplicate paths are forbidden.

Map style sources must reference `pmtiles://map.pmtiles`. Glyphs use
`glyphs/{fontstack}/{range}.pbf`, sprites use `sprites/sprite`. Map fonts are separate
from Flutter interface fonts. Include the glyph ranges used by your map labels.

## Test records

Feature IDs use F01 etc.; cases use T01 etc. Results have a build fingerprint,
timestamp, platform, status and evidence. Status is passed, failed, blocked or
not_run. The test dashboard imports only matching-build records. Human clinical
review is separate from automated content structure validation.

See [upgrade function contracts](upgrade.md) for question normalization, ranked search, Wikipedia saves, the rich reader, native example export and the isolated ZIM prototype.
