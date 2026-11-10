"""Fail-closed release evidence gate. Does not publish or alter store accounts."""
import datetime
import sys
from check import check, load, build_id, ROOT

def release_errors(config,policies,results):
    errors=[]
    flags=["application_id_confirmed","signing_configured","content_review_complete","translations_reviewed",
        "extended_translations_complete","physical_devices_tested","production_artifact_inspected",
        "store_disclosures_complete","licenses_reviewed","icons_and_screenshots_ready"]
    for key in flags:
        if config.get(key) is not True:errors.append(f"Release evidence missing: {key}")
    if not config.get("publisher"):errors.append("Publisher identity not configured")
    for key in ["privacy_url","support_url","catalog_url"]:
        if not str(config.get(key,"")).startswith("https://"):errors.append(f"Public HTTPS {key} required")
    if config.get("personal_account_testing") not in ["completed","not_applicable"]:errors.append("Google account testing applicability unresolved")
    if not config.get("evidence"):errors.append("No release evidence files")
    for path in config.get("evidence",[]):
        if not (ROOT/path).is_file():errors.append(f"Missing evidence file: {path}")
    for policy in policies:
        if policy["status"]!="verified" or not policy.get("evidence"):errors.append(f"{policy['id']}: policy evidence pending")
        if policy.get("verified_build")!=build_id():errors.append(f"{policy['id']}: policy must be rechecked for this build")
    if results.get("build")!=build_id():errors.append("Test evidence is not for current build")
    passed={r["id"] for r in results.get("results",[]) if r["status"]=="passed"}
    for case in load("registry/test_cases.json"):
        if case["type"]!="deferred" and case["id"] not in passed:errors.append(f"{case['id']}: acceptance evidence missing")
    return errors

def main():
    errors=check(release=True)+release_errors(load("registry/release.json"),load("registry/policies.json"),load("registry/results.json"))
    report={"build":build_id(),"generated_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "status":"blocked" if errors else "ready_for_submission_review","blockers":errors}
    (ROOT/"build").mkdir(exist_ok=True)
    import json
    (ROOT/"build/release-readiness.json").write_text(json.dumps(report,indent=2)+"\n")
    for error in errors:print("BLOCKED:",error)
    print(f"{len(errors)} release blockers. Report: build/release-readiness.json")
    return bool(errors)
if __name__=="__main__":sys.exit(main())
