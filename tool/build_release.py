"""Build with the shared VWorld default, using a CI variable or ignored key file."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    'android': ['appbundle', '--release'],
    'ios': ['ipa', '--release'],
    'web': ['web', '--release', '--target=lib/main_web.dart', '--base-href=/mungcation/', '--no-web-resources-cdn'],
    'apk': ['apk', '--debug'],
    'ios-simulator': ['ios', '--simulator', '--debug', '--no-codesign'],
}


def release_key(environment, path):
    key = environment.get('VWORLD_API_KEY', '').strip()
    if not key:
        try:
            key = json.loads(Path(path).read_text(encoding='utf-8-sig')).get('VWORLD_API_KEY', '').strip()
        except (OSError, ValueError, AttributeError):
            raise ValueError('Set VWORLD_API_KEY or create config/app_keys.json.') from None
    if not re.fullmatch(r'[A-Za-z0-9-]{10,128}', key):
        raise ValueError('A valid VWorld app key is required for this build.')
    return key


def build_command(target, define_file):
    return ['flutter', 'build', *TARGETS[target], f'--dart-define-from-file={define_file}']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=TARGETS)
    parser.add_argument('--keys-file', default=str(ROOT / 'config/app_keys.json'))
    parser.add_argument('--check', action='store_true', help='Validate the key configuration without building')
    args = parser.parse_args()
    try:
        key = release_key(os.environ, args.keys_file)
    except ValueError as error:
        parser.error(str(error))
    if args.check:
        print('VWorld default key configured.')
        return 0
    flutter = shutil.which('flutter')
    if not flutter:
        parser.error('Flutter SDK was not found on PATH.')
    # The file is temporary and its contents are never logged or committed.
    with tempfile.TemporaryDirectory(prefix='mungcation-build-') as folder:
        defines = Path(folder) / 'app_keys.json'
        defines.write_text(json.dumps({'VWORLD_API_KEY': key}), encoding='utf-8')
        command = build_command(args.target, str(defines))
        command[0] = flutter
        return subprocess.run(command, cwd=ROOT, check=False).returncode


if __name__ == '__main__':
    raise SystemExit(main())
