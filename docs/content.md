# Content and languages

## Current material

The bundled starter material is original draft editorial content. It covers all
requested categories in English and provides preparation/lost-person starter
cards in all nine languages. Expanded translations, specialist illustrations,
clinical review and regional foraging catalogs remain outstanding.

General decorative illustrations are not anatomical or plant-identification
evidence. Add reviewed explanatory illustrations when teaching detailed procedures.

## Add or edit an article

Edit [essential.json](../assets/content/essential.json) for bundled content, or
create `articles.json` in a separate pack directory. Use a stable ID; translated
versions share the ID but have different language codes. Include title, summary,
category, level, audience, region, prerequisites, sections, cautions, sources,
license, illustrations, update date and review fields.

Run `python3 tools/check.py`. A changed medical/technical article or translation
must return to draft until reviewed. Do not copy source content or artwork without
checking reuse rights. Document the actual reviewer and reviewed version.

Use `python3 tools/review_digest.py assets/content/essential.json` to identify the
exact text and metadata version under review. After independent approval, record
that value in `reviewed_content_sha256` with the reviewer and review date.
The command only computes a fingerprint; it never approves an article.
Publication and production installation reject changed content whose fingerprint
no longer matches. Illustration bytes also need independent review and must be
covered by the published pack's asset manifest.

`tools/seed_content.py` is a development seed generator: rerunning it overwrites
the starter files and resets them to draft. Do not use it to publish approved
editorial work.

## Add an illustration

Use an original or appropriately licensed SVG, PNG, JPEG or WebP. Keep text out of
the illustration where possible and use translated captions. Add its relative
path to the article. For clinical, water-treatment, mechanical, or identification
diagrams, obtain subject review of the image as well as the text.

## Add or correct a language

Edit the matching file in `assets/i18n`. Preserve all English keys. Add translated
articles and obtain independent translation review. For a new locale, add its code
and display name in models.dart, a supported bundled font, locale support, and
tests. Interface changes require an app update; content translations can ship as
packs. Do not silently present English as a completed translation.

## Build an optional content pack

```sh
python3 tools/publish_pack.py --source path/to/reviewed-pack \
  --output build/water-en.zip --id water-en --version 1.0.0 \
  --language en --kind content --url https://YOUR_HOST/water-en.zip
```

The tool writes an archive and catalog-entry JSON. Draft fixtures require the
explicit `--draft` flag and are rejected by the production installer. Upload
reviewed archives and the catalog to HTTPS storage supporting Range requests.
No hosting account or published endpoint is supplied by this repository.

## Map packs

Create a regional PMTiles extract from licensed open data, preserving attribution.
Supply a MapLibre style matching its source layers and all glyphs/sprites needed
for offline labels. Use `--kind map` with the same publishing tool. Test coverage,
labels and pan/zoom offline on both platforms before publishing. Do not use a
general-purpose public tile server for bulk downloads without permission.

## Corrections and rollback

Publish a new immutable version with a fresh hash. Never replace bytes at an
existing version URL. Content and user state are separate. Keep previous reviewed
archives available to republish a corrective version. An application rollback
requires a compatible store update; database downgrades are not automatic.

## Practical expansion and regional food

The 48 English practical drafts are authored in content/practical/en.json and compiled by `python3 tools/practical_content.py`. Add actual translations in the corresponding language files; never substitute English text under another language code. The compiler records actual counts in registry/content_coverage.json.

Six regional food editorial manifests live in content/food. They are not shipped identification instructions. Publication requires real licensed photographs, exact media hashes, captions, attribution, specialist and photo reviewer identities/dates, and separate translation review records. Both Python publishing validation and runtime pack admission enforce required-photo checks.

See [upgrade status](upgrade.md) for the remaining authored content and native archive work.
