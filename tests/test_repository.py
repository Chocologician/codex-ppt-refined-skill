"""仓库静态检查；不调用真实图片接口或桌面 PowerPoint。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / 'skills/codex-ppt'

class RepositoryTests(unittest.TestCase):
    def test_skill_frontmatter(self):
        text = (SKILL / 'SKILL.md').read_text(encoding='utf-8')
        data = yaml.safe_load(text.split('---', 2)[1])
        self.assertEqual(data['name'], 'codex-ppt')
        self.assertIsInstance(data['description'], str)
        self.assertGreater(len(data['description']), 10)
        self.assertTrue((SKILL / 'docs/editable-refined-animation.md').is_file())

    def test_attribution_and_license_travel_with_skill(self):
        license_text = (ROOT / 'LICENSE').read_text(encoding='utf-8')
        self.assertIn('Copyright (c) 2026 ningzimu', license_text)
        self.assertIn('MIT License', license_text)
        self.assertEqual((SKILL / 'LICENSE').read_bytes(), (ROOT / 'LICENSE').read_bytes())
        self.assertEqual((SKILL / 'NOTICE.md').read_bytes(), (ROOT / 'NOTICE.md').read_bytes())
        self.assertIn('ningzimu/codex-ppt-skill', (ROOT / 'README.md').read_text(encoding='utf-8'))

    def test_origin_manifest(self):
        manifest = json.loads((ROOT / 'UPSTREAM.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['upstreamAuthor'], 'ningzimu')
        if manifest['referenceCommit'] is not None:
            self.assertRegex(manifest['referenceCommit'], r'^[0-9a-f]{40}$')
        seen = set()
        for item in manifest['files']:
            with self.subTest(file=item['path']):
                self.assertNotIn(item['path'], seen)
                seen.add(item['path'])
                self.assertEqual(hashlib.sha256((ROOT / item['path']).read_bytes()).hexdigest(), item['sha256'])
                self.assertIn(item['origin'], ['extension', 'modified_upstream', 'upstream_snapshot'])
        declared = {p.relative_to(ROOT).as_posix() for p in SKILL.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name not in ['LICENSE', 'NOTICE.md']}
        self.assertEqual(seen, declared)

    def test_python_syntax(self):
        for file in ROOT.rglob('*.py'):
            if any(part in ['.git', '.venv', '.build'] for part in file.parts):
                continue
            with self.subTest(file=str(file)):
                ast.parse(file.read_text(encoding='utf-8-sig'), filename=str(file))

    def test_new_document_links(self):
        files = list(ROOT.glob('*.md')) + list((ROOT / 'docs').glob('*.md')) + list((ROOT / 'templates').glob('*.md')) + list((SKILL / 'docs').glob('*.md')) + list((ROOT / 'examples').glob('*/README.md')) + [SKILL / 'SKILL.md']
        for file in files:
            for target in re.findall(r'\]\(([^)]+)\)', file.read_text(encoding='utf-8')):
                if '://' in target or target.startswith('#'):
                    continue
                with self.subTest(file=file.name, target=target):
                    self.assertTrue((file.parent / target.split('#')[0]).exists())

    def test_feedback_forms(self):
        directory = ROOT / '.github/ISSUE_TEMPLATE'
        forms = [p for p in directory.glob('*.yml') if p.name != 'config.yml']
        self.assertGreaterEqual(len(forms), 2)
        for file in forms:
            form = yaml.safe_load(file.read_text(encoding='utf-8'))
            self.assertTrue(form['name'])
            ids = set()
            for field in form['body']:
                if field['type'] == 'markdown':
                    continue
                self.assertNotIn(field['id'], ids)
                ids.add(field['id'])
                self.assertTrue(field['attributes']['label'])
                if field['type'] == 'dropdown':
                    self.assertGreaterEqual(len(field['attributes']['options']), 2)

    def test_collaboration_entrypoints(self):
        config = (ROOT / '.github/ISSUE_TEMPLATE/config.yml').read_text(encoding='utf-8')
        self.assertIn('/discussions', config)
        self.assertIn('blank_issues_enabled: false', config)
        self.assertTrue((ROOT / 'docs/协作与讨论.md').is_file())
        self.assertIn('Pull Request', (ROOT / 'docs/协作与讨论.md').read_text(encoding='utf-8'))

    def test_maintenance_entrypoints(self):
        for relative in ['GOVERNANCE.md', 'ROADMAP.md', 'CONTRIBUTING.md', '.github/PULL_REQUEST_TEMPLATE.md', 'docs/测试说明.md', 'docs/发布与上游同步.md']:
            self.assertTrue((ROOT / relative).is_file())
        workflow = yaml.safe_load((ROOT / '.github/workflows/check.yml').read_text(encoding='utf-8'))
        self.assertIn('static', workflow['jobs'])
        self.assertIn('powershell-syntax', workflow['jobs'])

    def test_example_is_serial_and_identifies_source(self):
        plan = json.loads((ROOT / 'examples/animation-plan.example.json').read_text(encoding='utf-8'))
        self.assertRegex(plan['inputSha256'], r'^[0-9a-f]{64}$')
        for slide in plan['slides']:
            end = 0
            used = set()
            for group in slide['groups']:
                self.assertGreaterEqual(group['start'], end)
                self.assertGreater(group['duration'], 0)
                self.assertTrue(used.isdisjoint(group['shapeIds']))
                used.update(group['shapeIds'])
                end = group['start'] + group['duration']

    def test_no_private_deck_or_runtime_bundled(self):
        for file in SKILL.rglob('*'):
            if not file.is_file() or '__pycache__' in file.parts:
                continue
            self.assertNotIn('.venv', file.parts)
            self.assertNotEqual(file.name, '.env')
            self.assertNotIn(file.suffix.lower(), ['.pptx', '.pdf', '.mp4', '.doc', '.docx', '.pyc'])

if __name__ == '__main__':
    unittest.main()
