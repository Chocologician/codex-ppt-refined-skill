"""验证新贡献者登记文件时的真实行为，不访问网络。"""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('manifest_tool', ROOT / 'scripts/refresh_manifest.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)

class ManifestToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.path = 'skills/codex-ppt/docs/合成流程.md'
        file = self.root / self.path
        file.parent.mkdir(parents=True)
        file.write_text('# 合成流程\n', encoding='utf-8')
        (self.root / 'UPSTREAM.json').write_text(json.dumps({'files': []}), encoding='utf-8')

    def tearDown(self):
        self.temp.cleanup()

    def read(self):
        return json.loads((self.root / 'UPSTREAM.json').read_text(encoding='utf-8'))

    def test_register_and_refresh_keep_origin(self):
        tool.refresh(self.root, [self.path], 'extension')
        before = self.read()['files'][0]
        (self.root / self.path).write_text('# 改善后的流程\n', encoding='utf-8')
        tool.refresh(self.root)
        after = self.read()['files'][0]
        self.assertNotEqual(before['sha256'], after['sha256'])
        self.assertEqual(after['origin'], 'extension')

    def test_translation_requires_reference(self):
        with self.assertRaises(ValueError):
            tool.refresh(self.root, [self.path], 'modified_upstream')
        tool.refresh(self.root, [self.path], 'modified_upstream', 'skills/codex-ppt/docs/original.md')
        self.assertEqual(self.read()['files'][0]['referencePath'], 'skills/codex-ppt/docs/original.md')

    def test_registration_requires_explicit_origin(self):
        with self.assertRaises(ValueError):
            tool.refresh(self.root, [self.path])
        self.assertEqual(self.read()['files'], [])

    def test_reject_path_outside_skill(self):
        for path in ['README.md', '../escape.md', 'skills/codex-ppt/NOTICE.md']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                tool.refresh(self.root, [path], 'extension')

    def test_removal_requires_actual_deleted_file(self):
        tool.refresh(self.root, [self.path], 'extension')
        with self.assertRaises(ValueError):
            tool.refresh(self.root, removals=[self.path])
        (self.root / self.path).unlink()
        tool.refresh(self.root, removals=[self.path])
        self.assertEqual(self.read()['files'], [])

    def test_failure_does_not_partially_write(self):
        before = (self.root / 'UPSTREAM.json').read_bytes()
        with self.assertRaises(ValueError):
            tool.refresh(self.root, [self.path, 'skills/codex-ppt/missing.md'], 'extension')
        self.assertEqual((self.root / 'UPSTREAM.json').read_bytes(), before)

if __name__ == '__main__':
    unittest.main()
