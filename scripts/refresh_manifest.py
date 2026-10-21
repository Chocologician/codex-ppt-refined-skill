"""维护技能文件来源清单；归属必须显式登记，不自动推断。"""
from pathlib import Path
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {'LICENSE', 'NOTICE.md'}

def checked_path(root, value):
    file = (root / value).resolve()
    skill = (root / 'skills/codex-ppt').resolve()
    if not file.is_relative_to(skill) or file.name in EXCLUDED:
        raise ValueError('只允许登记技能目录内的运行文件；许可证与来源声明单独维护。')
    return file.relative_to(root.resolve()).as_posix()

def refresh(root, registrations=(), origin=None, reference_path=None, removals=()):
    root = Path(root).resolve()
    manifest_path = root / 'UPSTREAM.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    entries = {item['path']: dict(item) for item in manifest['files']}
    if registrations and origin not in {'extension', 'modified_upstream', 'upstream_snapshot'}:
        raise ValueError('登记新文件或变更归属需要明确指定来源分类。')
    if reference_path and len(registrations) != 1:
        raise ValueError('指定原始路径时，每次只登记一个文件。')
    for value in registrations:
        relative = checked_path(root, value)
        if not (root / relative).is_file():
            raise ValueError('待登记文件不存在：' + relative)
        previous = entries.get(relative, {})
        upstream = reference_path or previous.get('referencePath')
        if origin != 'extension' and not upstream:
            raise ValueError('上游文件或修改自上游的文件需要原始路径。')
        entries[relative] = {'path': relative, 'origin': origin,
                             'referencePath': None if origin == 'extension' else upstream}
    for value in removals:
        relative = checked_path(root, value)
        if (root / relative).exists():
            raise ValueError('文件仍然存在，不能只删除来源记录：' + relative)
        if relative not in entries:
            raise ValueError('该文件尚未登记：' + relative)
        del entries[relative]
    for relative, item in entries.items():
        checked_path(root, relative)
        file = root / relative
        if not file.is_file():
            raise ValueError('已登记文件缺失，请核对删除后使用 --remove：' + relative)
        item['sha256'] = hashlib.sha256(file.read_bytes()).hexdigest()
    manifest['files'] = [entries[key] for key in sorted(entries)]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return len(entries)

def main():
    parser = argparse.ArgumentParser(description='更新文件校验值，显式登记新增、翻译或移除的技能文件。')
    parser.add_argument('--register', action='append', default=[], help='新增或变更来源的技能文件路径，可重复')
    parser.add_argument('--origin', choices=['extension', 'modified_upstream', 'upstream_snapshot'], help='来源分类')
    parser.add_argument('--reference-path', help='对应上游原始文件路径')
    parser.add_argument('--remove', action='append', default=[], help='已确认删除的文件路径，可重复')
    args = parser.parse_args()
    if (args.origin or args.reference_path) and not args.register:
        parser.error('--origin 和 --reference-path 需要同时指定 --register')
    try:
        count = refresh(ROOT, args.register, args.origin, args.reference_path, args.remove)
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        parser.exit(1, '来源清单更新失败：' + str(error) + '\n')
    print(f'已更新 {count} 个文件的校验值，来源分类仅按显式参数变更。')

if __name__ == '__main__':
    main()
