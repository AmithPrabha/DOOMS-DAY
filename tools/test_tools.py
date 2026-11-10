import copy
import unittest
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from check import load, validate_content, validate_registry, validate_docs, validate_production_imports, review_digest
from release import release_errors
from docs import generate

class ToolTests(unittest.TestCase):
    def test_T33_python_example_restart_and_invalid_input(self):
        with tempfile.TemporaryDirectory() as directory:
            script=Path(directory)/"supplies.py"
            script.write_text(Path("assets/examples/supplies.py").read_text())
            first=subprocess.run([sys.executable,str(script)],
                input="set\ntorch\n2\nquit\n",text=True,capture_output=True,check=True)
            self.assertNotIn("Not saved",first.stdout)
            second=subprocess.run([sys.executable,str(script)],
                input="list\nset\ntorch\n-1\nquit\n",text=True,capture_output=True,check=True)
            self.assertIn("torch: 2",second.stdout)
            self.assertIn("Not saved",second.stdout)
            self.assertEqual(json.loads((Path(directory)/"supplies.json").read_text()),{"torch":2})
    def test_T29_food_photographs_and_reviews(self):
        content=load("assets/content/essential.json")
        article=copy.deepcopy(content["articles"][0])
        article.update(food_identification=True,media=[])
        errors=validate_content({"schema_version":1,"articles":[article]},require_languages=False)
        self.assertTrue(any("photographs missing" in e for e in errors))
        image=article["illustrations"][0]
        article["media"]=[dict(path=image,kind="photograph",ai_generated=False,
            required=True,caption="Test fixture only",attribution="Test fixture",
            license="Test fixture",source="https://example.org/photo",sha256="0"*64)]
        errors=validate_content({"schema_version":1,"articles":[article]},require_languages=False,release=True)
        self.assertTrue(any("reviewed bytes" in e for e in errors))
        self.assertTrue(any("specialist review" in e for e in errors))
    def test_T17_content_structure_and_review(self):
        content=load("assets/content/essential.json")
        self.assertEqual(validate_content(content),[])
        self.assertTrue(validate_content(content,release=True))
        bad=copy.deepcopy(content);bad["articles"][0]["illustrations"]=["assets/missing.svg"]
        self.assertTrue(any("missing or unsafe" in e for e in validate_content(bad)))
        bad=copy.deepcopy(content);bad["articles"][0]["sources"]=[]
        self.assertTrue(any("sources" in e for e in validate_content(bad)))
        reviewed=copy.deepcopy(content)
        for article in reviewed["articles"]:
            article.update(review_status="approved",translation_review="approved",
                reviewer="Automated test fixture only",reviewed_at="2026-10-20",license="Test fixture")
            article["reviewed_content_sha256"]=review_digest(article)
        self.assertEqual(validate_content(reviewed,release=True),[])
        reviewed["articles"][0]["title"]="Changed after review"
        self.assertTrue(any("content version" in e for e in validate_content(reviewed,release=True)))
    def test_T19_registry_and_docs(self):
        self.assertEqual(validate_registry(load("registry/features.json"),load("registry/test_cases.json")),[])
        self.assertEqual(validate_docs(),[])
        html=generate()
        self.assertIn('role="tablist"',html)
        self.assertIn('role="tabpanel"',html)
        self.assertNotIn('<script src=',html)
        bad=load("registry/features.json");bad[0]["tests"]=["MISSING"]
        self.assertTrue(validate_registry(bad,load("registry/test_cases.json")))
    def test_T18_production_import_graph(self):
        self.assertEqual(validate_production_imports(),[])
    def test_T20_release_fails_closed(self):
        errors=release_errors(load("registry/release.json"),load("registry/policies.json"),load("registry/results.json"))
        self.assertTrue(errors)
        self.assertTrue(any("Publisher" in e for e in errors))
        self.assertTrue(any("privacy_url" in e for e in errors))
if __name__=="__main__":unittest.main()
