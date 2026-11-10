See [upgrade status and maintenance map](docs/upgrade.md) for implemented features and remaining work.

# Dooms Day App — Offline survival reference

Flutter mobile application for Android and iPhone. Start with the offline
maintenance guide at `docs/guide.html` (generated with `python3 tools/docs.py`).

The [offline guide](docs/guide.html) includes features, flows, maintenance
walkthroughs, tests and release requirements. See [build evidence](docs/build-evidence.md)
for the verified Android/iPhone simulator builds and their limits.

## Development

Flutter is pinned in `.flutter-version`. Install that version or use the local
SDK at `.tooling/flutter/bin/flutter`.

```sh
python3 tools/check.py
python3 tools/docs.py
flutter pub get
flutter analyze
flutter test
python3 tools/flutter.py run development
```

Production entrypoint: `lib/main.dart`, flavor: `production`.
Use `python3 tools/release.py` before preparing any store submission.

## Release status

This repository is a development implementation, **not an approved medical
product or a store-ready release**. Draft articles and translations require
independent qualified review. Release validation deliberately fails until review,
hosting, publisher identity, signing, privacy disclosures, device evidence, and
store-account prerequisites have been completed. See `docs/release.md`.

Nothing in the application calculates medication doses, diagnoses a condition,
guarantees a plant is edible, or provides a live disaster advisory. The full
library is downloadable reference data, not downloaded executable application code.

## Navigation

- `lib/`: application, data repositories, device services and screens
- `assets/`: bundled handbook, translations, fonts, illustrations and catalogs
- `test/`, `integration_test/`: automated checks
- `registry/`: features, test cases, policy evidence and result records
- `tools/`: validation, documentation, pack publishing and build commands
- `docs/`: source documentation and standalone generated guide

Secrets, signing keys, build output, and the local SDK are not source files.
