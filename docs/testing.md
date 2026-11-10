# Tests

## Automated runs

Use `python3 tools/run_tests.py`. It runs Python validation tests, Flutter tests,
and records observed outcomes in `registry/results.json`. Never mark a case passed
because its test merely exists. A mixed or physical-device case remains incomplete
until its manual evidence is recorded.

Flutter tests cover SQLite search, data persistence, schema migration, pack
validation, update rollback, navigation mathematics, and large-text UI rendering.
Python tests cover content publication rules, documentation, registry mappings,
and release blockers.

Test Center's UI tab can open isolated previews for missing compass, denied GPS,
and an unavailable catalog. These fixtures never request device permissions.
The Diagnostics tab probes the real native compass with a five-second timeout;
availability does not establish accuracy. Results accept evidence notes and
matching-build automated JSON. They do not constitute medical review.

First launch and cold restart are mixed cases: SQLite checks provide automated
evidence, but their acceptance status remains not run until the complete
airplane-mode device scenario is recorded. `automated_status` retains partial
evidence without upgrading a mixed case to passed.

## Physical-device matrix

Test at least an older supported Android phone, a recent Android phone including
16 KB page-size compatibility, an older supported iPhone, and a recent iPhone.
Include a device without a compass where possible. Simulators do not verify
magnetometer behavior, battery use, background restrictions or real radio range.

For every run record platform, model, OS, build fingerprint, app flavor, network
state, steps, expected result, observed result, screenshots/logs and tester.

## Download interruption and cancellation: T08 / T09

Serve a valid pack from an HTTPS test host supporting Range requests. Start a
download, interrupt Wi-Fi, restart the app and resume. Check response ranges,
final hash, installed count and readable content. Repeat with a server that ignores
Range and with an incorrect Content-Range. Cancellation must leave a partial
download rather than a ready pack. Disable Wi-Fi with Wi-Fi-only enabled and check
that no cellular download continues.

## Low storage and safe updates: T12

Use a disposable emulator/device profile. Constrain free space below the required
archive plus expanded size and update workspace. Attempt a download. The old
version must still open. Then restore space and retry. Do not fill a personal
device as a test.

## Map, location and compass: T06 / T13 / T15

Install a reviewed regional map with glyphs and sprites. Disable networking and
cold-start. Pan, zoom and inspect non-Latin labels; verify no network font fetch.
Clear disposable caches without removing application data and repeat. Delete one
pack resource in a development fixture: verification must fail.

Deny location once and permanently; disable system location; test indoors without
a GPS fix. Check sensor absence and calibration messages. Move after obtaining a
fix and confirm the displayed timestamp makes stale data apparent.

## UI and accessibility

Exercise all screens in light/dark themes, all nine languages and at 200% text.
Use TalkBack and VoiceOver. Check contrast, reading order, focus, labels, and touch
targets. Core automated layouts are a starting point, not complete accessibility
certification. Capture visual baselines only after reviewing them.

## Production inspection: T18

Run `tools/check.py` to verify the production import graph. Inspect the actual APK,
AAB and IPA assets: development registry and fixtures must be absent. Launch the
production binary and verify there is no Test Center or reset route. Development
and production must install side by side without sharing data.

## Performance

Record store-download and installed sizes separately. Target less than 100 MB for
the store download, excluding optional packs. Measure cold startup, search with
large installed libraries, map memory, and battery use on representative hardware.
Record results rather than inventing thresholds met by unmeasured code.

The generated Tests tab includes the test register and build-specific outcomes.
Native compilation evidence and its limits are recorded in
[build-evidence.md](build-evidence.md).
