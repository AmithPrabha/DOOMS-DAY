# Dooms Day App upgrade: implementation status

This upgrade is in progress. Visible branding, quick controls, the compass dial,
reader improvements, English practical drafts and individual Wikipedia text saves
are implemented. The complete approved plan is not yet delivered.

| Area | Current implementation | Remaining work |
|---|---|---|
| Branding | Header, About, native display names and guide renamed; green vector-drawn compass app icon regenerated at platform resolutions | Physical icon and launch checks |
| Header | Shared persistent theme/language controller; 48-pixel controls; two-row narrow/large-text layout; native language names and font fallbacks | Physical VoiceOver/TalkBack evidence |
| Compass | Cardinal dial, ticks, upright labels, fixed forward indicator, shortest rotation, unavailable/poor-accuracy states, iOS orientation mapping | Physical portrait/landscape calibration and magnetic interference tests |
| Reader | Contents navigation, numbered instructions, horizontal code/table views, zoomable images, source metadata and Python file export | Full localization of new reader controls; reviewed photo assets in final food packs |
| Practical guides | 48 substantial English drafts bundled in development; original Python inventory example | 48 complete guides in each of the other eight languages; all independent reviews |
| Search | Offline SQLite BM25, question-prefix handling for nine languages, qualifier retention, paging, debounce and stale-future isolation | Curated language-specific synonyms and translated question datasets; archive search integration |
| Wikipedia pages | Explicit online search; save full supported textual content rather than summaries; source revision, license, attribution, update check; local links to already saved pages; removal preserves bookmarks | Optional image selection/attribution; richer HTML fidelity and curated multilingual collections; physical offline restart evidence |
| Full Wikipedia | Official OPDS parser, archive/job metadata tables, native C ABI and Dart isolate interface; iOS/Android arm64 compilation; macOS fixture runtime checks | App linkage, archive browser, background jobs, metalink acquisition, large-file recovery, local asset/link rendering, mobile runtime tests and licensing/distribution checks |
| Regional food | Six regional editorial manifests and fail-closed photograph/review validation | Regional specialist-authored entries, licensed reference photos and translation reviews; manifests are not published identification guides |

The normal app does not advertise a working full-Wikipedia downloader. Prototype
native libraries stay outside normal application artifacts until integrated and
verified. Unreviewed content does not become emergency answer material merely
because an automated test passes.

## Try this development build

Run `python3 tools/flutter.py run development` and choose Marshall. Native changes
require a fresh build, not only Flutter hot reload. Existing bundle identifiers,
signing team configuration, database filenames and development/production storage
roots are preserved.

- Switch theme in the header; open Settings and confirm the same selection.
- Open the language dropdown, choose Arabic and check direction. Select English
  reference in Library to read expanded English drafts from another interface language.
- Search `how to cook brown rice` or `how to create python application`.
- Open the Python inventory guide and use Save Python example to export through
  the platform document picker. The app never executes the code.
- In Library, explicitly open Online reference library, search Wikipedia, save a
  page, then return to Library. Disconnect internet, restart and reopen it.
- In Map, compare north/east/south/west against a known compass away from metal.

## Maintenance map

| Action | Source / symbol | Verification |
|---|---|---|
| Change header layout | lib/widgets/quick_header.dart / QuickHeader.build | T05, T25, T23 |
| Change persistent preferences | lib/core/providers.dart / PreferencesController.update | T07, T25 |
| Change compass drawing | lib/widgets/compass_dial.dart / CompassDial, headingDelta | T26 and physical T15 |
| Change question normalization | lib/data/knowledge_repository.dart / normalizeQuestion | T27 |
| Change ranking or pagination | lib/data/database.dart / rankedArticles | T27 |
| Change Wikipedia import | lib/services/wikipedia.dart / request, convertPage, save | T28 |
| Add practical translations | content/practical/LANGUAGE.json, tools/practical_content.py | T17, T31 |
| Change food publication checks | tools/check.py / validate_content; lib/services/packs.dart / validateArticle | T29 |
| Diagnose native archive prototype | native/zim/bridge.cpp, lib/services/zim_reader.dart | tools/test_zim_prototype.py; T30 |

## Important function contracts

QuickHeader.build reads current preferences and effective theme. A theme press
passes the opposite displayed brightness to PreferencesController.update; language
selection passes the selected language without a download. Errors show a message.
The controller updates the screen immediately, serializes database writes, and
rolls back the latest failed write. Callers are the header and Settings.

KnowledgeRepository.search receives a query, language, filters and page number.
It removes only recognized question prefixes and punctuation, then calls
AppDatabase.rankedArticles. The database performs bounded FTS5 retrieval ordered
by BM25; a page reads at most page size plus one rows. Output is KnowledgePage,
including hasMore. No network call occurs. SQL failures propagate to Library's
error state. Library debounces 250 ms and changes the FutureBuilder key when its
query context changes, preventing an older result from replacing a newer one.

WikipediaService.request accepts only supported Wikipedia language hosts and
bounded API responses. It has connection/read deadlines, rejects redirects and
returns decoded JSON or an error. convertPage parses HTML without a browser,
removes executable elements and builds text sections plus local-link targets.
It retains revision and license attribution and marks the record external.
save checks Wi-Fi preference, budget and free space, then atomically replaces
only that source-qualified page in SQLite. Existing bookmarks are separate.
Images, multimedia and interactive elements are explicitly omitted; saved pages
must not be used for food identification. hasUpdate makes an explicit online
revision check when pressed. No background polling occurs.

AppDatabase migration 2 to 3 adds archives and download_jobs metadata tables.
It does not rename, drop or rebuild bookmarks, preferences, places or packs.
The archive/job tables are preparatory; their presence is not evidence of native
background-download support.

ZimReader.request and asset run on worker isolates. The C ABI opens an archive
on demand, bounds result count and entry size, and returns owned buffers. Dart
copies bounded results and releases native memory in finally blocks. Missing
archives, entries and indexes return errors. See [native prototype](../native/zim/README.md).

## Content and recovery

Edit an authored language file, run `python3 tools/practical_content.py`, then
`python3 tools/check.py`. The compiler never manufactures missing translations
or grants reviews. registry/content_coverage.json records actual coverage.
Article review fingerprints bind approvals to exact content; changing steps,
media metadata or cautions invalidates approval. Required food photos need exact
hashes as well as real-photo provenance, attribution and specialist review.

If an individual page save fails, keep the existing SQLite record and retry when
space/network is available. There is no partially ready reference record. These
small page saves restart rather than resume. Existing optional-pack downloads
retain their separate resumable verified-install workflow.

Do not downgrade an app database by changing PRAGMA user_version. For app-update
recovery, preserve the support directory and restore a compatible app/database
backup. Optional content rollback and app database rollback are different tasks.
