"""检查公开演示是否自包含、可下载且与计划及核验记录一致。"""
from pathlib import Path
from collections import Counter
from zipfile import ZipFile
import hashlib
import json
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / 'examples/public-demo'
NS = {'p':'http://schemas.openxmlformats.org/presentationml/2006/main', 'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}

class PublicDemoTests(unittest.TestCase):
    def test_files_match_verification(self):
        record = json.loads((DEMO / 'verification.json').read_text(encoding='utf-8'))
        for name, expected in record['files'].items():
            self.assertEqual(hashlib.sha256((DEMO/name).read_bytes()).hexdigest(), expected)

    def test_plan_bound_to_shipped_source(self):
        plan = json.loads((DEMO / 'animation-plan.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(plan['inputSha256'].lower(), hashlib.sha256((DEMO/'source.pptx').read_bytes()).hexdigest())
        with ZipFile(DEMO/'source.pptx') as z:
            for entry in plan['slides']:
                xml=ET.fromstring(z.read(f'ppt/slides/slide{entry["slide"]}.xml'))
                ids={int(node.attrib['id']) for node in xml.findall('.//p:cNvPr',NS)}
                end=0
                for group in entry['groups']:
                    self.assertTrue(set(group['shapeIds']).issubset(ids))
                    self.assertGreaterEqual(group['start']+0.0001,end)
                    end=group['start']+group['duration']

    def test_native_content_preserved(self):
        with ZipFile(DEMO/'source.pptx') as source, ZipFile(DEMO/'animated.pptx') as target:
            self.assertIsNone(source.testzip())
            self.assertIsNone(target.testzip())
            for i in range(1,4):
                before=ET.fromstring(source.read(f'ppt/slides/slide{i}.xml'))
                after=ET.fromstring(target.read(f'ppt/slides/slide{i}.xml'))
                self.assertFalse(before.findall('.//p:pic',NS))
                self.assertEqual(Counter(t.text for t in before.findall('.//a:t',NS)), Counter(t.text for t in after.findall('.//a:t',NS)))
                self.assertTrue(after.findall('.//p:timing',NS))

    def test_demo_relative_runner_and_readme_present(self):
        self.assertTrue((DEMO/'run_demo.ps1').is_file())
        self.assertTrue((DEMO/'README.md').is_file())
        self.assertTrue((DEMO/'preview.gif').is_file())
