# Store release

The repository is not ready for public medical or emergency reliance. Draft
content and unverified device behavior are explicit release blockers.

## Gate and evidence

Run `python3 tools/release.py`. It produces `build/release-readiness.json` and exits
unsuccessfully while prerequisites are missing. Record evidence in
`registry/release.json`, `registry/policies.json`, and `registry/results.json`.
Never set a checkbox merely to obtain a successful exit.

Official requirements and the last verification date are in the Release tab.
Recheck those URLs for every submission. Store policies and SDK requirements change.

## Before external testing

- Confirm publisher identity, application IDs, developer-account type and target regions.
- Configure release signing securely and preserve recovery access.
- Review the generated original Dooms Day App icon and confirm final branding.
- Obtain expert and translation review and confirm content/map/font licenses.
- Host a complete public privacy policy and support page at working HTTPS URLs.
- Publish a verified content catalog with reviewer-accessible sample packs.
- Audit plugin permissions and privacy manifests against actual binary behavior.

The app uses local storage and foreground location. There is no analytics or
advertising SDK. Hosting and browser links have separate network data flows;
disclosures must cover these accurately. Third-party dependency declarations
still require inspection.

## Store forms

Complete Google Data Safety, health-app declaration, content rating, target
audience and app-access information. Complete Apple privacy labels, age-rating
questions, reviewer notes and region-specific declarations. Include a clear
medical-reference disclosure and consultation reminder. Do not claim diagnosis,
treatment, verified plant identification, or live disaster monitoring.

If applicable, meet Google's new personal-account closed-test requirements before
applying for production access. Use TestFlight for Apple beta testing.

## Binary checks

Verify Android target API 36 or newer against the current requirement and all
native libraries' 16 KB compatibility. Build using the current accepted Apple SDK.
Inspect required-reason APIs, signing, supported device OS versions, backup
behavior, network permissions and development-asset exclusion.

Location hardware is explicitly optional in the Android manifest; the handbook
must remain installable on devices without GPS. Check the merged APK manifest
after dependency updates so transitive permissions do not reintroduce store
hardware filtering.

Record successful physical-device tests, screenshots and measured performance.
App-store approval is not guaranteed by this checklist.

## Reviewer notes template

Dooms Day App is an offline reference app. No login is required. Essential content is
bundled; optional packs require an internet connection only to download. Location
permission is requested only on tapping Locate. Medical content is informational,
with sources and review records. Supply actual sample-pack URLs and specific
navigation instructions for the submitted build.

## Release and recovery

Tag the reviewed source and archive the toolchain, signed artifacts and evidence.
Use staged rollout where available. Monitor platform crash reports and user
support without adding undisclosed telemetry. Stop rollout when a critical defect
is confirmed. Correct content through a new reviewed pack; correct executable
behavior through a store update with a compatible database migration.
