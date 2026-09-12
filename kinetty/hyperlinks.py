# Port of the wezterm hyperlink_rules (../wezterm/wezterm.lua) as a
# kitty hints kitten, matching raw screen text with regexes (no OSC 8).
# Used by: map cmd+shift+e kitten hints --customize-processing hyperlinks.py

import re

# (regex, url_template, highlight_group) applied in order; earlier rules
# win on overlap, like wezterm. highlight_group is the group whose span
# is marked for selection (0 = the whole match; None = groups 1-3 for
# the username/project rule).
RULES = [
    # Rewrite bare: ssh://github.com/...  -->  https://github.com/...
    (r'\bssh://(github\.com)/?([^\s)\]\}>]*)?', r'https://\1/\2', 0),
    # Matches: a URL in parens: (URL)
    (r'\((\w+://\S+)\)', r'\1', 1),
    # Matches: a URL in brackets: [URL]
    (r'\[(\w+://\S+)\]', r'\1', 1),
    # Matches: a URL in curly braces: {URL}
    (r'\{(\w+://\S+)\}', r'\1', 1),
    # Matches: a URL in angle brackets: <URL>
    (r'<(\w+://\S+)>', r'\1', 1),
    # Then handle URLs not wrapped in brackets
    (r'(?<![({\[<])\b\w+://\S+', r'\g<0>', 0),
    # implicit mailto link
    (r'\b\w+@[\w-]+(\.[\w-]+)+\b', r'mailto:\g<0>', 0),
    # make username/project paths clickable. this implies paths like the
    # following are for github.
    # ( "nvim-treesitter/nvim-treesitter" | wbthomason/packer.nvim )
    (r'["\'\s]([\w\d]{1}[-\w\d]+)(/){1}([-\w\d.]+)["\'\s]',
     r'https://www.github.com/\1/\3', None),
    # Example:
    #     ruff: Mixed spaces and tabs [E101]
    (r'🔗🐍 \[(\w+)\]', r'https://docs.astral.sh/ruff/rules/\1', 0),
    (r'🔗🐍b \[(\w+)\]',
     r'https://docs.basedpyright.com/latest/configuration/config-files/#\1', 0),
    (r'🔗🐚 \[(\w+)\]', r'https://shellcheck.net/wiki/\1', 0),
    # rustc error
    (r'🔗🦀 \[E([0-9]+)\]', r'https://doc.rust-lang.org/error_codes/E\1.html', 0),
    # rustc lint warning
    (r'🔗🦀 \[([a-z0-9_]+)\]', r'https://doc.rust-lang.org/rustc/?search=\1', 0),
    # clippy
    (r'🔗🦀cl \[([a-z0-9_]+)\]',
     r'https://rust-lang.github.io/rust-clippy/master/index.html#\1', 0),
    (r'🔗🌜d \[(.*)\]', r'https://luals.github.io/wiki/diagnostics/#\1', 0),
    (r'🔗🌜s \[(.*)\]', r'https://luals.github.io/wiki/syntax-errors/#\1', 0),
    # biome
    (r'🔗 \[([a-z0-9-]+)]', r'https://biomejs.dev/linter/rules/\1', 0),
    (r'\[lint/.*/(.*)\]', r'https://next.biomejs.dev/linter/rules/\1', 0),
    # selene
    (r'🔗selene \[([a-z0-9_]+)\]',
     r'https://kampfkarren.github.io/selene/lints/\1.html', 0),
]

COMPILED = [(re.compile(pat), template, group) for pat, template, group in RULES]


def mark(text, args, Mark, extra_cli_args, *a):
    marks = []
    occupied = []
    for pattern, template, group in COMPILED:
        for m in pattern.finditer(text):
            if group is None:
                start, end = m.start(1), m.end(3)
            elif group == 0 or m.start(group) == -1:
                start, end = m.span()
            else:
                start, end = m.span(group)
            if any(s < end and start < e for s, e in occupied):
                continue
            occupied.append((start, end))
            # \0 marks wrapped lines in the screen text kitty hands us
            url = m.expand(template).replace('\0', '')
            mark_text = text[start:end].replace('\n', '').replace('\0', '')
            marks.append((start, end, mark_text, url))
    marks.sort()
    for idx, (start, end, mark_text, url) in enumerate(marks):
        yield Mark(idx, start, end, mark_text, {'url': url})


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    for groupdict in data['groupdicts']:
        url = groupdict.get('url')
        if url:
            boss.open_url(url)
