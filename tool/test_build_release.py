import json
from pathlib import Path
import tempfile
import unittest
from build_release import release_key, build_command


class ReleaseMapTest(unittest.TestCase):
    def test_key_comes_from_ci_or_private_local_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'app_keys.json'
            path.write_text(json.dumps({'VWORLD_API_KEY': 'local-test-key-12345'}))
            self.assertEqual(release_key({}, path), 'local-test-key-12345')
            self.assertEqual(release_key({'VWORLD_API_KEY': 'ci-test-key-12345'}, path), 'ci-test-key-12345')

    def test_a_release_never_silently_builds_without_a_map_key(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'missing.json'
            for env in [{}, {'VWORLD_API_KEY': 'bad/key'}, {'VWORLD_API_KEY': 'YOUR_VWORLD_APP_KEY'}]:
                with self.assertRaises(ValueError):
                    release_key(env, path)

    def test_all_platform_builds_receive_the_same_define_file(self):
        for target, output in [('android', 'appbundle'), ('ios', 'ipa'), ('web', 'web'), ('apk', 'apk'), ('ios-simulator', 'ios')]:
            command = build_command(target, 'private.json')
            self.assertEqual(command[:3], ['flutter', 'build', output])
            self.assertIn('--dart-define-from-file=private.json', command)
        self.assertIn('--release', build_command('android', 'private.json'))
        self.assertIn('--base-href=/mungcation/', build_command('web', 'private.json'))


if __name__ == '__main__':
    unittest.main()
