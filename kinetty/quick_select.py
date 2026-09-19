# Port of wezterm's quick select mode (ctrl+shift+space) as a kitty hints
# kitten: the same default patterns, in the same order, so the same text
# gets a hint. Used by: ctrl+shift+space in kinetty.toml, which copies the
# pick with --program @. (wezterm copies on the label and pastes on
# shift+label; the hints kitten reads only lowercase labels, so this copies.)

import re

# wezterm-gui/src/overlay/quickselect.rs, in wezterm's order: it joins them
# into one alternation, so at every position the first pattern that matches
# wins. Four of them extract a group; the copied text is that group.
PATTERNS = [
    # markdown_url
    r'\[[^]]*\]\(([^)]+)\)',
    # url
    r'(?:https?://|git@|git://|ssh://|ftp://|file://)\S+',
    # diff_a
    r'--- a/(\S+)',
    # diff_b
    r'\+\+\+ b/(\S+)',
    # docker
    r'sha256:([0-9a-f]{64})',
    # path
    r'(?:[.\w\-@~]+)?(?:/+[.\w\-@]+)+',
    # color
    r'#[0-9a-fA-F]{6}',
    # uuid
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    # ipfs
    r'Qm[0-9a-zA-Z]{44}',
    # sha
    r'[0-9a-f]{7,40}',
    # ip
    r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
    # ipv6
    r'[A-f0-9:]+:+[A-f0-9:]+[%\w\d]+',
    # address
    r'0x[0-9a-fA-F]+',
    # number
    r'[0-9]{4,}',
]

# No outer group, so m.lastindex names the group of whichever alternative
# matched, or is None when that alternative has none.
COMBINED = re.compile('|'.join(f'(?:{p})' for p in PATTERNS))


def haystacks(text):
    """Yield (line, offsets) per logical line of the screen text kitty hands
    over, where a row that soft-wraps ends in \\r, a logical line in \\n, and an
    unwritten cell is \\0. A match may run across a wrap but never across \\n,
    and blank cells separate like spaces, which is how wezterm searches its
    joined rows. offsets[i] is where line[i] sits in text."""
    pos = 0
    for raw in text.split('\n'):
        chars, offsets = [], []
        for i, ch in enumerate(raw):
            if ch != '\r':
                chars.append(' ' if ch == '\0' else ch)
                offsets.append(pos + i)
        yield ''.join(chars), offsets
        pos += len(raw) + 1


def mark(text, args, Mark, extra_cli_args, *a):
    index = 0
    for line, offsets in haystacks(text):
        for m in COMBINED.finditer(line):
            start, end = m.span(m.lastindex or 0)
            if end <= start:
                continue
            yield Mark(index, offsets[start], offsets[end - 1] + 1, line[start:end], {})
            index += 1
