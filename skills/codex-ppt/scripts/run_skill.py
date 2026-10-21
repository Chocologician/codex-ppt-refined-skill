"""统一命令入口：需要依赖的操作始终使用共享运行环境的解释器。"""
from pathlib import Path
import argparse
import os
import subprocess
import sys

SCRIPTS = {
    'bootstrap': ('codex_ppt_runtime.py', 'bootstrap'),
    'doctor': ('codex_ppt_runtime.py', 'doctor'),
    'config': ('codex_ppt_runtime.py', 'config'),
    'image-gen': ('image_gen.py', None),
    'assemble': ('assemble_ppt.py', None),
    'prepare': ('prepare_slide_prompts.py', None),
    'status': ('slide_job_status.py', None),
    'record-dispatch': ('record_slide_dispatch.py', None),
    'record-result': ('record_slide_result.py', None),
    'record-blocker': ('record_slide_blocker.py', None),
}

def runtime_python(home=None, platform=None):
    home = Path(home or os.environ.get('CODEX_PPT_HOME', '~/.codex-ppt-skill')).expanduser()
    if (platform or os.name) == 'nt':
        return home / '.venv/Scripts/python.exe'
    return home / '.venv/bin/python'

def command_for(command, arguments, home=None, platform=None):
    filename, prefix = SCRIPTS[command]
    interpreter = sys.executable if prefix else str(runtime_python(home, platform))
    return [interpreter, str(Path(__file__).resolve().parent / filename)] + ([prefix] if prefix else []) + list(arguments)

def printable_command(command):
    result = list(command)
    for i, value in enumerate(result):
        if value == '--api-key' and i + 1 < len(result):
            result[i + 1] = '<已隐藏>'
        elif value.startswith('--api-key='):
            result[i] = '--api-key=<已隐藏>'
    return result

def child_environment():
    environment = os.environ.copy()
    # 上游日志含勾号等符号，Windows默认GBK不能稳定编码；仅调整本次子进程。
    environment['PYTHONUTF8'] = '1'
    environment['PYTHONIOENCODING'] = 'utf-8'
    return environment

def main():
    parser = argparse.ArgumentParser(description='运行技能脚本，自动选择正确解释器；不会隐式安装依赖。')
    parser.add_argument('--show-command', action='store_true', help='仅展示将使用的命令，不执行；密钥参数隐藏')
    parser.add_argument('command', choices=SCRIPTS, help='bootstrap安装运行依赖；doctor诊断；config配置；image-gen生图；assemble组装')
    parser.add_argument('arguments', nargs=argparse.REMAINDER, help='传给底层脚本的原始参数')
    args = parser.parse_args()
    command = command_for(args.command, args.arguments)
    if args.show_command:
        import json
        print(json.dumps(printable_command(command), ensure_ascii=False))
        return 0
    if SCRIPTS[args.command][1] is None and not Path(command[0]).is_file():
        print('共享运行环境尚未安装。请先运行：', file=sys.stderr)
        print(f'python "{Path(__file__).resolve()}" bootstrap', file=sys.stderr)
        return 2
    try:
        return subprocess.run(command, check=False, env=child_environment()).returncode
    except OSError as error:
        print('无法启动运行环境：' + str(error), file=sys.stderr)
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
