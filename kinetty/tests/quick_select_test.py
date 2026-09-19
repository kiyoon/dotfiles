"""Tests for quick_select.py, the wezterm quick-select port used by
ctrl+shift+space. Runs against the fork's venv (pyrefly.toml names it):

    /Users/kiyoon/project/wezterm-gureum/kitty/.venv/bin/python -m pytest kinetty/tests/quick_select_test.py

kitty hands the hints kitten the screen as text where every row that
soft-wraps ends in \\r, every logical line ends in \\n, and unwritten cells
are \\0. The marks it takes back are (start, end) offsets into that same
text, so the tests check both the copied text and the offsets.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import quick_select  # noqa: E402


class Mark:
    """Stand-in for kittens.hints.main.Mark with the same constructor."""

    def __init__(self, index, start, end, text, groupdict, is_hyperlink=False, group_id=None):
        self.index, self.start, self.end, self.text = index, start, end, text
        self.groupdict = groupdict


def marks(text):
    return list(quick_select.mark(text, None, Mark, ()))


def texts(text):
    return [m.text for m in marks(text)]


def test_offsets_index_the_original_text():
    text = 'see https://example.com/a/very/long/pa\rth?x=1 now\n--- a/src/foo.py\nport 8080\0\0\n'
    for m in marks(text):
        assert text[m.start:m.end].replace('\r', '') == m.text
        assert m.end > m.start


def test_url_wrapped_over_two_rows_is_one_mark():
    assert texts('see https://example.com/a/very/long/pa\rth?x=1 now\n') == [
        'https://example.com/a/very/long/path?x=1',
    ]


def test_indices_follow_document_order():
    assert [m.index for m in marks('https://a.b/x\nhttps://c.d/y\n')] == [0, 1]


def test_blank_cells_separate_like_spaces():
    # Unwritten cells between two words must not glue them into one path.
    assert texts('foo/bar\0\0baz/qux\n') == ['foo/bar', 'baz/qux']


def test_markdown_link_copies_only_the_url():
    assert texts('[docs](https://example.com/docs) here\n') == ['https://example.com/docs']


def test_diff_headers_copy_the_path_without_the_prefix():
    assert texts('--- a/src/foo.py\n+++ b/src/foo.py\n') == ['src/foo.py', 'src/foo.py']


def test_docker_digest_copies_the_hex_only():
    digest = 'a' * 64
    assert texts(f'Digest: sha256:{digest}\n') == [digest]


def test_earlier_pattern_wins_at_the_same_position():
    # wezterm lists address (0x...) before it would ever see the sha inside
    # it, so the whole 0xdeadbeef is one match, not deadbeef.
    assert texts('addr 0xdeadbeef sha deadbeefcafe1234\n') == ['0xdeadbeef', 'deadbeefcafe1234']


def test_other_default_patterns():
    text = (
        'ip 192.168.0.1 port 8080 color #ff00aa\n'
        'uuid 123e4567-e89b-12d3-a456-426614174000\n'
        '~/project/x/y.txt and ./rel/path\n'
    )
    assert texts(text) == [
        '192.168.0.1', '8080', '#ff00aa',
        '123e4567-e89b-12d3-a456-426614174000',
        '~/project/x/y.txt', './rel/path',
    ]


def test_hard_line_end_is_never_crossed():
    assert texts('https://a.b/c\nd/e\n') == ['https://a.b/c', 'd/e']


def test_no_marks_on_plain_prose():
    assert texts('just some words here\n') == []
