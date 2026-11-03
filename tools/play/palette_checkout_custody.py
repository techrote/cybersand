"""Allowed checkout digests from independently authenticated Git attributes.

This is a deliberately narrow, pure reader for this qualification's source
archive. It does not read worktree/global Git configuration or normalize an
observed digest. The caller authenticates the complete archive and supplies
every archived .gitattributes file. Only an explicit effective text/eol=crlf
rule adds a transformed form; exact archived bytes always remain identifiable.
The hosted checkout prescribes core.autocrlf=false and core.eol=lf, so the
unqualified text=auto default grants no additional CRLF form.
"""
from __future__ import annotations

import hashlib
import re


MAX_ATTRIBUTE_FILES = 256
MAX_ATTRIBUTE_BYTES = 1024 * 1024
_NONTRANSFORMING = frozenset(('diff=lfs', 'merge=lfs', 'whitespace=cr-at-eol'))


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _relative(value: object) -> str:
    _require(type(value) is str and bool(value) and '\\' not in value
             and ':' not in value and '\0' not in value and not value.startswith('/')
             and all(part not in ('', '.', '..') for part in value.split('/')),
             'Unsafe source/attribute path')
    return value


def _matches(pattern: str, relative: str) -> bool:
    # Support the repository's positive basename and path globs. Unsupported
    # Git wildmatch/quoting/macro syntax is never silently reinterpreted.
    _require(pattern and not pattern.startswith(('!', '[attr]'))
             and not any(char in pattern for char in ('\\', '"', '[', ']', '\0'))
             and '**' not in pattern and not pattern.endswith('/'),
             'Unsupported Git attribute pattern')
    anchored = pattern.startswith('/')
    pattern = pattern[1:] if anchored else pattern
    _require(pattern and all(part not in ('', '.', '..') for part in pattern.split('/')),
             'Unsafe Git attribute pattern')
    candidate = relative if anchored or '/' in pattern else relative.rsplit('/', 1)[-1]
    expression = ''.join('[^/]*' if char == '*' else '[^/]' if char == '?'
                         else re.escape(char) for char in pattern)
    return re.fullmatch(expression, candidate) is not None


def _attributes(relative: str, files: dict[str, bytes]) -> dict[str, object]:
    _require(type(files) is dict and 0 < len(files) <= MAX_ATTRIBUTE_FILES
             and '.gitattributes' in files, 'Authenticated root Git attributes required')
    total = 0; ordered = []
    for name, data in files.items():
        name = _relative(name)
        _require(name.rsplit('/', 1)[-1] == '.gitattributes' and type(data) is bytes,
                 'Invalid authenticated Git attribute file')
        total += len(data)
        _require(total <= MAX_ATTRIBUTE_BYTES, 'Git attribute evidence capacity exceeded')
        parent = name.rsplit('/', 1)[0] if '/' in name else ''
        ordered.append((parent.count('/') + bool(parent), name, parent, data))
    effective: dict[str, object] = {}
    for _, name, parent, data in sorted(ordered):
        if parent and not relative.startswith(parent + '/'):
            continue
        local = relative[len(parent) + 1:] if parent else relative
        try:
            lines = data.decode('utf-8-sig').splitlines()
        except UnicodeError as error:
            raise ValueError('Git attributes are not UTF-8: ' + name) from error
        for line in lines:
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            fields = line.split()
            _require(len(fields) >= 2, 'Git attribute rule lacks attributes')
            matches = _matches(fields[0], local)
            if not matches:
                continue
            for attribute in fields[1:]:
                if attribute in ('text', '-text', '!text', 'text=auto'):
                    effective['text'] = {'text': True, '-text': False, '!text': None,
                                         'text=auto': 'auto'}[attribute]
                elif attribute in ('eol=lf', 'eol=crlf', '!eol'):
                    effective['eol'] = None if attribute == '!eol' else attribute.split('=', 1)[1]
                elif attribute == 'filter=lfs':
                    effective['filter'] = 'lfs'
                elif attribute not in _NONTRANSFORMING:
                    raise ValueError('Unsupported relevant Git attribute: ' + attribute)
    return effective


def allowed_checkout_digests(relative: str, canonical_bytes: bytes,
                             authenticated_attribute_files: dict[str, bytes]) -> set[str]:
    """Return exact source and explicitly declared CRLF checkout SHA-256 forms.

    LFS payloads are independently authenticated by the caller. This helper
    grants no filtered, encoding-converted, mixed-EOL or binary transformation.
    Unknown relevant rules fail closed, even if the supplied bytes are exact.
    """
    relative = _relative(relative)
    _require(type(canonical_bytes) is bytes, 'Canonical source must be exact bytes')
    effective = _attributes(relative, authenticated_attribute_files)
    digests = {hashlib.sha256(canonical_bytes).hexdigest()}
    if effective.get('eol') != 'crlf' or effective.get('text') in (False, 'auto'):
        return digests
    _require(effective.get('filter') is None, 'Filtered source cannot grant a text checkout form')
    # eol implies text when unspecified. Refuse to guess Git's text=auto
    # binary classification or normalize a pre-existing mixed/CRLF archive.
    if b'\0' not in canonical_bytes and b'\r' not in canonical_bytes:
        digests.add(hashlib.sha256(canonical_bytes.replace(b'\n', b'\r\n')).hexdigest())
    return digests
