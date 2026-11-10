"""Initialize the maintainable feature/test catalog; review changes before rerunning."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def write(name,data):
    (R/"registry"/name).write_text(json.dumps(data,indent=2,ensure_ascii=False)+"\n")

items=[
("F01","Emergency shortcuts and handbook","lib/features/handbook.dart",["T01","T02","T23"],"implemented","Draft content; expert review outstanding"),
("F02","Search, categories, aliases and bookmarks","lib/data/database.dart",["T03","T04"],"implemented","Full-text SQLite search; expanded translations pending"),
("F03","Nine languages, offline fonts and Arabic RTL","lib/app.dart",["T05","T06"],"partial","Core labels and two starter cards per language; extended UI/content translation pending"),
("F04","Themes, font scale and preferences","lib/features/settings.dart",["T05","T07"],"implemented","Human accessibility review pending"),
("F05","Preparation checklist","lib/features/handbook.dart",["T07"],"implemented","Saved locally"),
("F06","Download, resume and cancellation","lib/services/packs.dart",["T08","T09"],"implemented_unverified","HTTP resumption requires device/host integration evidence"),
("F07","Pack integrity, safe updates and removal","lib/services/packs.dart",["T10","T11","T04"],"implemented","Publisher hosting not configured"),
("F08","Storage budget and free-space checks","lib/services/packs.dart",["T09","T12"],"implemented_unverified","Native disk-space channel requires devices"),
("F09","Offline MapLibre map packs","lib/features/maps.dart",["T13","T14"],"implemented_unverified","Regional archive and real-device evidence required"),
("F10","GPS, compass and saved places","lib/services/navigation.dart",["T15","T16"],"implemented_unverified","Physical sensor tests pending"),
("F11","Medicine and specialist content","assets/content/essential.json",["T17"],"draft","Not clinical guidance; independent review blocks publication"),
("F12","Development Test Center","lib/development/test_center.dart",["T18","T24"],"implemented","Production has separate entrypoint and assets; controlled device/network fixtures"),
("F13","Local documentation and feature register","tools/docs.py",["T19"],"implemented","Regenerate after every change"),
("F14","Store readiness and privacy","tools/release.py",["T20"],"blocked","Publisher, hosting, declarations, signing and device evidence needed"),
("F15","Schema upgrades and recovery","lib/data/database.dart",["T21"],"implemented","Migration fixtures included"),
("F16","Nearby messaging","docs/architecture.md",["T22"],"deferred","Phase two: direct peer messaging; hardware integrations later"),
]
dependencies={
    "F01":["F02","F03","F11"], "F02":["SQLite FTS5","Drift"], "F03":["Bundled Noto fonts","flutter_localizations"],
    "F04":["Riverpod","SQLite preferences"],"F05":["SQLite checklist"],
    "F06":["HTTPS catalog host","F07","F08"],"F07":["archive","crypto","Drift transactions"],
    "F08":["Native free-space channel"],"F09":["MapLibre","Reviewed PMTiles packs","F07"],
    "F10":["geolocator","Native compass adapters"],"F11":["Independent subject and language reviewers"],
    "F12":["Development flavor","F13"],"F13":["Python 3.10+","Feature/test registries"],
    "F14":["Developer accounts","Signing","Hosting","Physical-device evidence","F11"],
    "F15":["Drift"],"F16":["Future native transport","Peer security design","Store policy review"],
}
write("features.json",[dict(id=i,title=t,purpose=notes,dependencies=dependencies[i],
    source=s,tests=tests,status=status,notes=notes) for i,t,s,tests,status,notes in items])
tests=[
("T01","First launch offline","Essential starter cards open without network on first device launch","mixed","test/database_test.dart"),
("T02","Cold restart offline","Content, illustrations, bookmarks, search and installed maps survive a device restart offline","mixed","test/database_test.dart"),
("T03","Alias and punctuation search","APAP finds acetaminophen; malformed search input cannot break SQL","automated","test/database_test.dart"),
("T04","Pack removal","Search is updated; bookmarks survive removal and reinstall","automated","test/database_test.dart"),
("T05","Text, theme and RTL layouts","Core screens render in nine languages at large text without overflow","automated","test/ui_test.dart"),
("T06","Offline glyph rendering","All scripts are readable on physical devices with networking disabled","manual","docs/testing.md"),
("T07","Preferences and checklist","Preferences and checklist survive restart","automated","test/database_test.dart"),
("T08","Interrupted HTTP download","Partial downloads resume correctly after network interruption","manual","docs/testing.md"),
("T09","Cancellation and network policy","Wi-Fi-only is respected; cancellation leaves resumable data","manual","docs/testing.md"),
("T10","Corruption, traversal and collision","Invalid packages cannot replace working content or write outside storage","automated","test/packs_test.dart"),
("T11","Atomic activation","Failed installation preserves previous working version and search","automated","test/packs_test.dart"),
("T12","Low storage","Insufficient disk space prevents writes without losing installed content","manual","docs/testing.md"),
("T13","Offline map and cache cleanup","Map geometry, labels and sprites survive restart and cache cleanup","manual","docs/testing.md"),
("T14","Map integrity","Missing map resources invalidate readiness","automated","test/packs_test.dart"),
("T15","Permissions and absent sensors","Denied GPS or missing compass produces a useful fallback","manual","docs/testing.md"),
("T16","Coordinate validation and bearing","Invalid coordinates are rejected; known distances and bearings are correct","automated","test/navigation_test.dart"),
("T17","Content review and publication","Incomplete provenance, missing images or unreviewed content block publication","automated","tools/test_tools.py"),
("T18","Production development exclusion","Production entrypoint cannot reach development tools; asset inspection excludes test fixtures","mixed","tools/check.py"),
("T19","Documentation navigation","Links, source paths and feature-to-test references resolve","automated","tools/test_tools.py"),
("T20","Store release gate","Missing evidence prevents production release packaging","automated","tools/test_tools.py"),
("T21","Migration from previous database","Schema upgrades preserve personal data and installed pack metadata","automated","test/database_test.dart"),
("T22","Nearby communication","Android/iPhone peers connect with consent and accurate delivery status","deferred","docs/architecture.md"),
("T23","Visual regression baselines","English/light and Arabic/dark emergency screens match reviewed macOS baselines","automated","test/golden_test.dart"),
("T24","Controlled device and network fixtures","Missing compass and denied GPS show fallback; unavailable catalog preserves content","automated","test/fixtures_test.dart"),
]
write("test_cases.json",[dict(id=i,title=t,feature_ids=[f[0] for f in items if i in f[3]],
    prerequisites="Pinned toolchain and development fixtures; physical device for manual cases",
    steps=[f"Follow {source}",t,"Compare actual outcome with expected result"],
    expected=expected,type=kind,source=source,platforms=["Android","iOS"],build=None,
    outcome="not_run",evidence=[]) for i,t,expected,kind,source in tests])
policies=[
("P01","Android API target and native page alignment","https://developer.android.com/google/play/requirements/target-sdk",
 "API 36; verify all native libraries on a 16 KB device","android/app/build.gradle.kts"),
("P02","Apple SDK, privacy manifest and required reason APIs","https://developer.apple.com/news/upcoming-requirements/",
 "Xcode 26+ and current submission SDK; audit every native dependency","ios/Runner/PrivacyInfo.xcprivacy"),
("P03","Google health content declaration and disclosures","https://support.google.com/googleplay/android-developer/answer/16679511?hl=en",
 "Complete health declaration, medical disclosures and public privacy URL","docs/release.md"),
("P04","Apple medical content","https://developer.apple.com/app-store/review/guidelines/",
 "Reviewed reference content; no dose calculators; clinical consultation reminder","lib/features/settings.dart"),
("P05","Google personal account testing","https://support.google.com/googleplay/android-developer/answer/14151465?hl=en",
 "If personal account created after 2023-11-13: 12 opted-in testers for 14 consecutive days","docs/release.md"),
("P06","16 KB compatibility","https://developer.android.com/guide/practices/page-sizes",
 "Inspect release native libraries and test on a 16 KB device","docs/release.md"),
]
write("policies.json",[dict(id=i,title=t,url=url,verified_at="2026-10-20",verified_build=None,requirement=req,
    applicability="Account-dependent" if i=="P05" else "Required for production submission",
    implementation=path,status="pending_evidence",outstanding_actions=req,evidence=[]) for i,t,url,req,path in policies])
write("release.json",dict(publisher=None,application_id_confirmed=False,privacy_url=None,support_url=None,
    catalog_url=None,signing_configured=False,content_review_complete=False,
    translations_reviewed=False,extended_translations_complete=False,
    physical_devices_tested=False,production_artifact_inspected=False,
    store_disclosures_complete=False,licenses_reviewed=False,icons_and_screenshots_ready=False,
    personal_account_testing="unknown",evidence=[]))
write("results.json",dict(build=None,generated_at=None,results=[]))
