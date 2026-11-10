"""Compile original practical drafts. Never grants content/translation approval.
Translations are independent files in content/practical/<language>.json; missing
translations are reported, never filled with English under another language tag.
"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ('en','ar','ml','hi','ta','te','es','fr','ru')

def compile_content():
    articles=[]; coverage={}
    for language in LANGUAGES:
        path=ROOT/'content/practical'/f'{language}.json'
        rows=json.loads(path.read_text()) if path.exists() else []
        coverage[language]=len(rows)
        for row in rows:
            assert row['language']==language
            articles.append(row)
    (ROOT/'assets/content/practical.json').write_text(json.dumps(
        {'schema_version':1,'articles':articles},ensure_ascii=False,indent=2)+'\n')
    (ROOT/'registry/content_coverage.json').write_text(json.dumps(
        {'target_per_language':48,'authored':coverage,'reviewed':{
            language:sum(a['language']==language and a['review_status']=='approved'
                         and a['translation_review']=='approved' for a in articles)
            for language in LANGUAGES}},indent=2)+'\n')
    print('Practical drafts:',coverage)

if __name__=='__main__': compile_content()
