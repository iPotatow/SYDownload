#!/usr/bin/env python3
"""Check packaging's Swift invocations using the system Bash (3.2 on macOS)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class PackageAppTests(unittest.TestCase):
    def test_swift_build_arguments(self):
        repo = Path(__file__).resolve().parent.parent
        for sdk, configuration in ((None, 'release'), ('', 'release'),
                                   ('/tmp/SDK with spaces', 'debug')):
            with self.subTest(sdk=sdk), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                log = root / 'swift-args.jsonl'
                uname = root / 'uname'
                uname.write_text('#!/bin/sh\nprintf "Darwin\\n"\n')
                swift = root / 'swift'
                swift.write_text(
                    '#!/usr/bin/env python3\n'
                    'import json, os, sys\n'
                    'with open(os.environ["SWIFT_ARGS_LOG"], "a") as log:\n'
                    '    log.write(json.dumps(sys.argv[1:]) + "\\n")\n'
                    '# Stop before any bundle staging or macOS-only tooling.\n'
                    'if "--show-bin-path" in sys.argv:\n'
                    '    sys.exit(99)\n'
                )
                uname.chmod(0o755)
                swift.chmod(0o755)
                env = os.environ.copy()
                env.pop('SWIFT_SDK', None)
                env.update(PATH=str(root) + os.pathsep + env['PATH'],
                           SWIFT_ARGS_LOG=str(log), CONFIGURATION=configuration,
                           APP_VERSION='0.3.12', SPARKLE_PUBLIC_ED_KEY='test-key')
                if sdk is not None:
                    env['SWIFT_SDK'] = sdk
                result = subprocess.run(
                    ['/bin/bash', str(repo / 'script/package_app.sh')],
                    cwd=repo, env=env, text=True, capture_output=True,
                )
                self.assertEqual(result.returncode, 99, result.stderr)
                calls = [json.loads(line) for line in log.read_text().splitlines()]
                common = ['build', '-c', configuration]
                if sdk:
                    common += ['--sdk', sdk]
                self.assertEqual(calls, [common + ['--product', 'SYDownload'],
                                         common + ['--show-bin-path']])


if __name__ == '__main__':
    unittest.main()
