# Native encyclopedia prototype

This is an isolated prototype, not a shipped full-Wikipedia feature. The normal
Flutter app does not link these libraries. No large archive is downloaded by default.

The C ABI in bridge.cpp opens ZIM files through libzim, inspects metadata, pages
full-text search results, reads text entries and returns bounded binary assets.
Archive data remains in the original ZIM. Entry reads are capped at 16 MB. Search
pages are capped at 100 entries. Native errors become structured errors; ownership
of returned buffers transfers to the caller, which must call dd_zim_free.

The Dart ZimReader uses an isolate for each operation and frees every native buffer.
It does not render HTML or enable scripts. Before connecting it to the app reader,
add local internal-link and asset resolution and a renderer with no automatic
external requests. Never pass archive HTML to an unrestricted WebView.

## Reproduce

- Run `python3 tools/fetch_zim.py` from the repository root.
- Run `python3 tools/build_zim_prototype.py` on the pinned macOS/Xcode/NDK toolchain.
- Run `python3 tools/test_zim_prototype.py` for the host runtime fixture checks.
- Inspect build/zim-prototype/build.json, runtime.json and build.log.

The exact official dependency URLs and SHA-256 values are in dependencies.json.
The Apple archive includes device, simulator and macOS slices. Android is currently
arm64 only. Its libzim ELF load segments were inspected at 16 KB alignment; that
is not evidence of an entire signed application passing store checks.

## Publication gate

libzim is GPL-2.0-or-later. CoreKiwix includes additional libraries with their own
terms. These local compilation experiments do not complete the application's
licensing, corresponding-source, reproducible-build or store-distribution work.
Do not add binary artifacts to production until those checks are complete.

Still required: native app integration, persistent background download scheduling,
metalink checksum/mirror handling, interruption/low-space recovery, safe updates,
archive removal, mobile runtime and large-archive performance tests, all-ABI
packaging and production distribution review. Archives lacking a full-text index
return an explicit error instead of being described as fully searchable.

Catalog discovery is in lib/services/kiwix_catalog.dart. Acquisition URLs can end
in .meta4 and must be resolved as metalink descriptors. Mini editions contain
introductions; they must not be labelled complete Wikipedia.

Official references:
- https://github.com/openzim/libzim
- https://github.com/kiwix/kiwix-apple
- https://opds.library.kiwix.org/catalog/v2/root.xml
