#!/usr/bin/env python3
"""Adverse controls for source-bound checkout EOL forms."""
import hashlib
from pathlib import Path
import unittest

import palette_checkout_custody as checkout


def digest(data):
    return hashlib.sha256(data).hexdigest()


class CheckoutCustodyTests(unittest.TestCase):
    def setUp(self):
        self.attributes = {'.gitattributes': b'* text=auto\n*.ps1 text eol=crlf\n*.bat text eol=crlf\n*.py text eol=lf\n'}
        self.canonical = b'first line\nsecond line\n'
        self.crlf = self.canonical.replace(b'\n', b'\r\n')

    def forms(self, path, data=None, attrs=None):
        return checkout.allowed_checkout_digests(path, self.canonical if data is None else data,
                                                self.attributes if attrs is None else attrs)

    def test_declared_real_launcher_extensions_allow_complete_crlf(self):
        for path in ('build_windows_msvc.bat', 'tools/launch_desktop.ps1'):
            with self.subTest(path=path):
                self.assertEqual(self.forms(path), {digest(self.canonical), digest(self.crlf)})

    def test_lf_auto_and_undeclared_files_do_not_gain_crlf(self):
        for path in ('tools/play/run.py', 'image.svg', 'nested/script.PS1'):
            with self.subTest(path=path):
                self.assertEqual(self.forms(path), {digest(self.canonical)})

    def test_partial_crlf_whitespace_and_content_changes_are_not_allowed(self):
        forms = self.forms('tools/launch.ps1')
        for changed in (b'first line\r\nsecond line\n', self.crlf + b'\r\n',
                        self.crlf.replace(b'first', b'changed'), self.crlf.replace(b'line', b'line ')):
            with self.subTest(changed=changed):
                self.assertNotIn(digest(changed), forms)

    def test_nested_override_and_later_matching_rule_are_respected(self):
        attrs = self.attributes | {'tools/.gitattributes': b'*.ps1 text eol=lf\nkeep.ps1 text eol=crlf\n'}
        self.assertEqual(self.forms('tools/run.ps1', attrs=attrs), {digest(self.canonical)})
        self.assertIn(digest(self.crlf), self.forms('tools/deeper/keep.ps1', attrs=attrs))
        self.assertIn(digest(self.crlf), self.forms('outside/run.ps1', attrs=attrs))

    def test_path_globs_are_anchored_and_stars_do_not_cross_slashes(self):
        attrs = {'.gitattributes': b'* text=auto\ntools/*.ps1 text eol=crlf\n/root.bat text eol=crlf\n'}
        self.assertIn(digest(self.crlf), self.forms('tools/run.ps1', attrs=attrs))
        for path in ('tools/nested/run.ps1', 'other/tools/run.ps1', 'nested/root.bat'):
            self.assertEqual(self.forms(path, attrs=attrs), {digest(self.canonical)})
        self.assertIn(digest(self.crlf), self.forms('root.bat', attrs=attrs))

    def test_unset_text_and_reset_eol_do_not_grant_crlf(self):
        for rule in (b'*.ps1 -text\n', b'*.ps1 !eol\n', b'*.ps1 text=auto eol=crlf\n'):
            attrs = {'.gitattributes': self.attributes['.gitattributes'] + rule}
            self.assertEqual(self.forms('run.ps1', attrs=attrs), {digest(self.canonical)})

    def test_binary_or_preexisting_mixed_archive_keeps_only_exact_bytes(self):
        for data in (b'binary\0\n', self.crlf, b'first\r\nsecond\n', b'bare\rcarriage\n'):
            self.assertEqual(self.forms('run.ps1', data), {digest(data)})

    def test_lfs_negative_text_never_transforms_pointer(self):
        attrs = {'.gitattributes': b'* text=auto\n*.dll filter=lfs diff=lfs merge=lfs -text\n'}
        self.assertEqual(self.forms('native.dll', attrs=attrs), {digest(self.canonical)})

    def test_unknown_relevant_transformations_and_syntax_fail_closed(self):
        for rule in (b'*.ps1 working-tree-encoding=UTF-16\n', b'*.ps1 filter=arbitrary\n',
                     b'*.ps1 binary\n', b'**/*.ps1 text eol=crlf\n',
                     b'"path with space.ps1" text eol=crlf\n', b'!run.ps1 text\n'):
            with self.subTest(rule=rule), self.assertRaises(ValueError):
                self.forms('run.ps1', attrs={'.gitattributes': rule})

    def test_missing_or_unsafe_attribute_authority_is_rejected(self):
        for attrs in ({}, {'other/.gitattributes': b'* text\n'},
                      {'.gitattributes': 'not bytes'},
                      {'.gitattributes': b'* text\n', '../.gitattributes': b'* text\n'}):
            with self.subTest(attrs=attrs), self.assertRaises(ValueError):
                self.forms('run.ps1', attrs=attrs)
        for path in ('../run.ps1', '/run.ps1', 'C:/run.ps1', 'tools\\run.ps1', 'a//run.ps1'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.forms(path)

    def test_receipt_cannot_supply_an_unregistered_normalization(self):
        # The observed hash stays raw. A caller checks membership; the helper
        # never maps arbitrary observed bytes into a source-looking digest.
        actual = digest(b'first line\r\nmodified second line\r\n')
        self.assertNotIn(actual, self.forms('tools/launch.ps1'))

    def test_current_authenticated_attributes_cover_both_real_launchers(self):
        root = Path(__file__).resolve().parents[2]
        attrs = {'.gitattributes': (root / '.gitattributes').read_bytes()}
        for path in ('build_windows_msvc.bat', 'tools/launch_desktop.ps1'):
            data = (root / path).read_bytes().replace(b'\r\n', b'\n')
            self.assertIn(digest(data.replace(b'\n', b'\r\n')),
                          checkout.allowed_checkout_digests(path, data, attrs))
        self.assertEqual(checkout.allowed_checkout_digests('godot/example.gd', self.canonical, attrs),
                         {digest(self.canonical)})


if __name__ == '__main__':
    unittest.main()
