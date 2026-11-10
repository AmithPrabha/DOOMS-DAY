# Build and tools

## Pinned tools

Flutter 3.44.4 and Dart 3.12.2 are pinned in [.flutter-version](../.flutter-version).
Direct dependencies are pinned in [pubspec.yaml](../pubspec.yaml); transitive versions
are committed in [pubspec.lock](../pubspec.lock). Python 3.10+ runs repository tools.
Xcode project editing uses xcodeproj 1.27.0.

The Android project uses its checked-in Gradle wrapper and requires JDK 21
(MapLibre's native compilation requirement) and Android SDK 36. Native iOS builds require macOS, Xcode, and plugin dependency
resolution. Do not infer store submission readiness from a successful debug build.

Minimum supported OS: Android 7/API 24 and iOS 15. The iOS minimum reflects the
supported deployment range of the installed Xcode 27.1 SDK, independently of the
submission SDK requirement.

## First setup

```sh
flutter doctor -v
flutter pub get
python3 tools/check.py
python3 tools/docs.py
flutter analyze
flutter test
```

A local SDK, when installed, is `.tooling/flutter/bin/flutter`.
Install the Android SDK using Android Studio or the command-line tools. Accept
licenses interactively after reading them. Confirm connected devices with
`flutter devices`.

## Run

### If Flutter says "No supported devices connected"

This project targets Android and iOS. Chrome and macOS desktop are not app targets.
Downloading Flutter's desktop/web SDK files does not install a mobile simulator.

On the development Mac, Xcode 27.1 is installed. The simulator runtime and device
list were empty when checked on 20 October 2026.

Install an iOS simulator runtime once:

```sh
xcodebuild -downloadPlatform iOS
```

Wait for installation to finish; this is a large download. Alternatively, use
Xcode Settings → Components to install iOS simulator support.
Xcode 27 calls the Simulator application Device Hub:

```sh
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
```

Create/select an iPhone simulator using the installed iOS runtime and start it.
Once its home screen is visible, run these commands from the project folder:

```sh
.tooling/flutter/bin/flutter devices
python3 tools/flutter.py run development
```

The devices list must contain an iPhone/iOS simulator. If multiple mobile devices
are available, choose the desired target, or append `-d DEVICE_ID` using its
identifier from the devices list. Xcode 26 and earlier use `open -a Simulator`.
See the [official Flutter iOS setup instructions](https://docs.flutter.dev/platform-integration/ios/setup).

To test on an Android phone instead, enable Developer options and USB debugging,
connect it with a data-capable USB cable, and accept its debugging authorization
prompt. Then run the same development command. Real iPhone testing additionally
requires device trust, Developer Mode, and development signing.

### Install on your own iPhone

Use a data-capable USB cable, unlock the iPhone, and accept "Trust This Computer".
Open Xcode and let it finish pairing/preparing the phone. On iOS 16 or later,
enable Settings → Privacy & Security → Developer Mode, restart, and confirm.
If Developer Mode is missing, connect and pair with Xcode first.

Open the workspace from the project folder:

```sh
open ios/Runner.xcworkspace
```

In Xcode Settings → Accounts, sign in with your Apple Account. A free Personal
Team supports personal device testing; App Store distribution requires the
appropriate paid membership. In the project editor select the Runner project,
then TARGETS → Runner → Signing & Capabilities. Enable automatic signing and
choose your team for the development configurations. The repository has no
developer team configured.

The development bundle identifier is `org.fieldkit.fieldkit.dev`. If Xcode says
it cannot register that identifier, use a unique development identifier such as
`com.YOURNAME.fieldkit.dev`; retain a distinct production identifier.
Select the `development` scheme and your physical iPhone as destination.
Let Xcode resolve signing before running from the terminal:

```sh
.tooling/flutter/bin/flutter devices
python3 tools/flutter.py run development
```

If multiple devices appear, append `-d DEVICE_ID` using the phone identifier.
If iOS reports an untrusted developer, open Settings → General → VPN & Device
Management, select your developer identity and complete the trust prompts.

For testing independent launches and offline restarts without an attached
debugger, install the development flavor in profile mode:

```sh
python3 tools/flutter.py run development --profile
```

Keep the phone connected and unlocked until installation and first launch finish.
Development signing remains subject to the team's provisioning validity.
See [Flutter's physical iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup)
and [Apple's device deployment guide](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).

### Manual smoke test

- Open Emergency and read a starter article. Draft labels are expected.
- Open Library, search `APAP`, open the medicine reference and bookmark it.
- Change theme, text size and language in Settings; check Arabic reading order.
- Close and reopen the app; confirm preferences and bookmarks remain.
- Open Settings → Test Center. Try isolated UI previews, content validation,
  feature checks, diagnostics, and record observations in Results.
- On a physical phone, test cold launch in airplane mode, denied location and
  compass behavior. Simulator sensor readings do not prove physical accuracy.

An empty download catalog and missing regional map are currently expected until
a pack host and reviewed map packs are configured. Use the development flavor
for reviewing starter content; the production flavor filters unapproved drafts.

During `flutter run`, `r` reloads UI changes, `R` restarts the app, and `q` ends
the run. The maintenance HTML is separate from the mobile application:

```sh
open docs/guide.html
```

### Flavor commands

```sh
python3 tools/flutter.py run development
python3 tools/flutter.py run production
```

The wrapper selects the local toolchain when available and injects the content/code
fingerprint used by Test Center evidence. Direct Flutter commands are supported,
but unversioned builds cannot record current-build acceptance results.
The production app only loads approved content. The release gate currently blocks
publication because starter material is draft. This is intentional, not a database
failure.

## Catalog configuration

```sh
python3 tools/flutter.py run development \
  --dart-define=PACK_CATALOG_URL=https://YOUR_HOST/catalog.json
```

The URL is public configuration, never a private API key. Without it, the catalog
is empty and the bundled handbook still works.

## Test and inspect

```sh
python3 tools/run_tests.py
flutter test integration_test/offline_test.dart --flavor development \
  -t integration_test/offline_test.dart -d DEVICE_ID
```

Enable airplane mode on the device before running the offline integration scenario.
The test cannot itself prove network isolation: capture device settings and
network evidence in the manual record.

## Build artifacts

```sh
python3 tools/flutter.py apk development
python3 tools/flutter.py ios-simulator development
python3 tools/release.py
python3 tools/flutter.py appbundle production
python3 tools/flutter.py ipa production
```

Configure release signing in secure local configuration or CI secret storage first.
Never commit keystores, certificates, profiles, private keys, or account credentials.
The Android release configuration does not silently sign with debug credentials.

## Reproducibility

Record the build fingerprint from `tools/check.py`, Flutter doctor output, platform
SDK versions, commit, and device OS. Build both flavors after dependency changes.
The `tools/configure_ios.rb` script creates development/production schemes
idempotently if you need to regenerate project configuration.

To install the exact project-editing tool locally when regeneration is needed:

```sh
gem install xcodeproj -v 1.27.0 --install-dir .tooling/gems --no-document
GEM_HOME="$PWD/.tooling/gems" GEM_PATH="$PWD/.tooling/gems" ruby tools/configure_ios.rb
```

Normal builds use the checked-in schemes and do not require this regeneration.

Simulator builds target arm64 on Apple Silicon (use an x86_64 override on an Intel Mac). This avoids the
multi-architecture lipo verification incompatibility observed with Flutter 3.44.4
and Xcode 27.1. Physical-device architectures are unchanged. The compass uses
native Android rotation-vector and iOS heading adapters; all external iOS plugins
use Swift Package Manager, so this project does not need CocoaPods.

Inspect compiled artifacts with `tools/inspect_artifact.py PATH --flavor production
--output build/inspection.json`. It checks development-asset/code exclusion and
64-bit ELF load-segment alignment. It does not replace installation, 16 KB device
tests, privacy audits or a release-size measurement.

`python3 tools/verify_builds.py` builds and inspects both flavors on both platforms
sequentially, saving logs and JSON evidence under `build/`. Use `--platform android`
or `--platform ios` on a platform-specific CI worker. Simulator app bundles are
preserved separately in `build/artifacts/` so one flavor cannot overwrite the other.
