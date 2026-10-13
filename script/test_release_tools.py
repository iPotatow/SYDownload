#!/usr/bin/env python3
"""Smoke-test bundle link checks and real Sparkle signing with a disposable key."""
import base64
import importlib.util
import os
import secrets
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

# Exercise the real packaging script with the system Bash before signing tests.
subprocess.run(['python3', 'script/test_package_app.py'], check=True)

def module(name):
    spec = importlib.util.spec_from_file_location(name, Path('script') / (name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

links = module('verify_bundle_links')
with tempfile.TemporaryDirectory() as folder:
    root = Path(folder) / 'App'; root.mkdir()
    (root / 'version').mkdir(); (root / 'current').symlink_to('version')
    links.verify(root)
    (root / 'bad').symlink_to(Path(folder))
    try: links.verify(root)
    except ValueError: pass
    else: raise AssertionError('escaping link accepted')
    (root / 'bad').unlink(); (root / 'bad').symlink_to('missing')
    try: links.verify(root)
    except FileNotFoundError: pass
    else: raise AssertionError('broken link accepted')

appcast = module('generate_sparkle_appcast')
os.environ['SPARKLE_PRIVATE_ED_KEY'] = base64.b64encode(secrets.token_bytes(32)).decode()
with tempfile.TemporaryDirectory() as folder:
    root = Path(folder); archive = root / 'SYDownload.zip'; archive.write_bytes(b'test archive contents')
    appcast.generate(root, '0.3.12', 'iPotatow/SYDownload')
    enclosure = ET.parse(root / 'appcast.xml').find('channel/item/enclosure')
    signature = enclosure.get('{'+appcast.SPARKLE+'}edSignature')
    signer = next(Path('.build/artifacts').glob('*/*/bin/sign_update'))
    subprocess.run([str(signer.resolve()), '--verify', '--ed-key-file', '-', str(archive), signature], input=os.environ['SPARKLE_PRIVATE_ED_KEY']+'\n', text=True, check=True, capture_output=True)
print('PASS: internal/escaping/broken links and real EdDSA appcast signature verification')
