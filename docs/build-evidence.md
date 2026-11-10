# Build evidence

Verified locally on 20 October 2026 with Flutter 3.44.4, Dart 3.12.2,
JDK 21.0.12.1, Android SDK 36, NDK 28.2.13676358 and Xcode 27.1.
Source fingerprint: `eb985b70a7b5baeb`. See [build records](../registry/builds.json).

| Artifact | Build and static inspection | Size |
|---|---|---|
| android development debug | passed | 213.2 MiB |
| android production debug | passed | 213.1 MiB |
| ios development debug | passed | 147.3 MiB |
| ios production debug | passed | 147.3 MiB |

Production artifacts exclude development routes, fixtures and the test registry.
The existing application IDs and Xcode signing team are preserved. All inspected
64-bit Android ELF load segments pass static 16 KB alignment checks. Runtime
compatibility on a 16 KB device remains unverified.

The automated suite contains 45 passing Flutter tests and six passing Python
checks. It includes first-run storage, migration from version 2, narrow Arabic
interaction, preferences, question queries, external HTML import, food publication
checks and a restart test of the exported Python example. Mixed/manual acceptance
cases remain not run until their complete device evidence is recorded. Test
results do not approve medical material or translations.

The matching development artifact was installed and launched on the iPhone 18 Pro
iOS 27.0 simulator. Its installed Dart kernel matches the inspected artifact, and
the Emergency screen visibly renders the new branding and quick controls.
The local screenshot is `build/upgrade-simulator.png`. This is a launch smoke
check, not physical-device or offline-content acceptance evidence.

Native ZIM probes compile for Android arm64, iOS arm64, iOS simulator arm64 and
macOS arm64. A synthetic host archive passes metadata, search, read and missing-file
checks. These libraries are not linked into normal app artifacts. Mobile runtime,
all-ABI packaging, background transfers, large-archive memory/performance and
licensing/distribution checks remain outstanding.

Debug APK and uncompressed simulator bundle sizes are not store-download sizes.
The less-than-100-MB store target, battery use, cold-start latency and large-library
performance remain unmeasured. No signed AAB/IPA, store upload or publication was
performed. Physical sensor accuracy, offline regional maps, screen-reader behavior,
required food photographs and airplane-mode first launch still need device evidence.

Run `python3 tools/verify_builds.py` for both flavors and
`python3 tools/run_tests.py` for build-specific results. Native probe reproduction
is documented in [the prototype guide](../native/zim/README.md). The complete
remaining scope is in [upgrade status](upgrade.md).
