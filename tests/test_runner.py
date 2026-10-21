"""统一入口的解释器选择与参数传递，无网络调用。"""
from pathlib import Path
import importlib.util
import tempfile
import unittest
import sys
import os

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('skill_runner', ROOT / 'skills/codex-ppt/scripts/run_skill.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class RunnerTests(unittest.TestCase):
    def test_dependency_commands_use_shared_python(self):
        with tempfile.TemporaryDirectory() as directory:
            for platform in ['nt', 'posix']:
                for command in ['image-gen', 'assemble']:
                    actual = runner.command_for(command, ['文件 名.pptx'], directory, platform)
                    self.assertEqual(actual[0], str(runner.runtime_python(directory, platform)))
                    self.assertEqual(actual[-1], '文件 名.pptx')

    def test_setup_uses_current_python_and_subcommand(self):
        for command in ['bootstrap', 'config', 'doctor']:
            actual = runner.command_for(command, ['--help'])
            self.assertEqual(actual[0], sys.executable)
            self.assertEqual(actual[-2:], [command, '--help'])

    def test_printed_key_is_redacted(self):
        original = ['python', '--api-key', 'example-secret', '--api-key=other-secret']
        result = runner.printable_command(original)
        self.assertNotIn('example-secret', repr(result))
        self.assertNotIn('other-secret', repr(result))
        self.assertEqual(original[2], 'example-secret')

    def test_unknown_command_rejected(self):
        with self.assertRaises(KeyError):
            runner.command_for('arbitrary.py', [])

    def test_utf8_child_does_not_modify_parent_environment(self):
        before = dict(os.environ)
        child = runner.child_environment()
        self.assertEqual(child['PYTHONUTF8'], '1')
        self.assertEqual(child['PYTHONIOENCODING'], 'utf-8')
        self.assertEqual(dict(os.environ), before)
