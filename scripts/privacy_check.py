#!/usr/bin/env python3
"""Fail closed before publishing an explicitly selected source or app archive."""
import argparse
from pathlib import Path
import re
import stat
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PUBLIC = ['Package.swift', 'README.md', 'LICENSE', 'SECURITY.md', 'CONTRIBUTING.md',
          'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md', '.gitignore', 'Sources', 'Tests',
          'Resources', 'scripts', 'docs', 'examples', '.github']
PATTERNS = {
    'absolute home path': re.compile(rb'/Users/(?!test(?:/|\b)|example(?:/|\b))[A-Za-z0-9_.-]+(?:/|\x00)'),
    'private key': re.compile(rb'-----BEGIN [A-Z ]*PRIVATE KEY-----'),
    'GitHub credential': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'AWS access key': re.compile(rb'AKIA[A-Z0-9]{16}'),
    'API key': re.compile(rb'sk-[A-Za-z0-9_-]{30,}'),
}
DENIED_SUFFIXES = {'.p12', '.pfx', '.pem', '.key', '.log', '.mobileprovision', '.provisionprofile'}

def source_files():
    result = []
    for name in PUBLIC:
        path = ROOT / name
        if path.is_symlink():
            raise ValueError('Symlink in public source selection')
        if not path.exists():
            raise ValueError('Missing public source entry: ' + name)
        for item in ([path] if path.is_file() else sorted(path.rglob('*'))):
            if item.is_symlink():
                raise ValueError('Symlink in public source: ' + str(item.relative_to(ROOT)))
            if item.is_file():
                if item.name == '.DS_Store' or item.name.startswith('._'):
                    continue
                if item.suffix in DENIED_SUFFIXES or item.name.startswith('.env'):
                    raise ValueError('Private file in public source selection')
                result.append(item)
    return sorted(result)

def inspect(path):
    data = path.read_bytes()
    for label, pattern in PATTERNS.items():
        if pattern.search(data):
            raise ValueError('Potential ' + label + ' in ' + path.name + ' (value withheld)')

def inspect_app(app):
    allowed = {'Contents/Info.plist', 'Contents/MacOS/MailSwitch',
               'Contents/Resources/AppIcon.icns', 'Contents/Resources/LICENSE',
               'Contents/Resources/THIRD_PARTY_NOTICES.md',
               'Contents/Resources/hello.eml',
               'Contents/Frameworks/libswift_Concurrency.dylib',
               'Contents/_CodeSignature/CodeResources'}
    if app.is_symlink():
        raise ValueError('Symlinked application bundle')
    actual = set()
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Unexpected symlink in application bundle')
        if path.is_file():
            actual.add(path.relative_to(app).as_posix())
            inspect(path)
    if actual != allowed:
        raise ValueError('Unexpected/missing app files: ' + ', '.join(sorted(actual ^ allowed)))

def archive_sources(paths):
    destination = ROOT / 'dist' / 'MailSwitch-source.zip'
    if destination.parent.is_symlink() or destination.is_symlink():
        raise ValueError('Symlinked source archive destination')
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            # Construct entries, rather than copying owner names or filesystem metadata.
            info = zipfile.ZipInfo('MailSwitch/' + path.relative_to(ROOT).as_posix(), (2026, 1, 1, 0, 0, 0))
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    print('Created dist/MailSwitch-source.zip')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path)
    parser.add_argument('--archive', action='store_true')
    args = parser.parse_args()
    try:
        paths = source_files()
        for path in paths:
            inspect(path)
        if args.app:
            inspect_app(args.app)
        if args.archive:
            archive_sources(paths)
        print('PASS: publication checks (' + str(len(paths)) + ' source files)')
    except (ValueError, OSError) as error:
        parser.exit(1, 'Publication check failed: ' + str(error) + '\n')
