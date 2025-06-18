# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "humanize",
#     "humanfriendly",
#     "cyclopts",
# ]
# ///

import json
import os
import pprint
import sys

import humanize
from cyclopts import App, Parameter
from humanfriendly import parse_size

app = App(
    help_format="markdown",
    default_parameter=Parameter(
        consume_multiple=True,  # Allow list of arguments without repeating --option a --option b ..
        negative=False,  # Do not make --no-option as a boolean flag
    ),
)


def traverse_dust_json(node, size_map):
    """
    Recursively traverse a JSON node with keys 'size', 'name', 'children',
    parse size to bytes, and record into size_map[name] = bytes.
    """
    try:
        size_bytes = parse_size(node.get("size", "0B"))
    except Exception:
        size_bytes = 0
    path = node.get("name", "")
    size_map[path] = size_bytes
    for child in node.get("children", []):
        traverse_dust_json(child, size_map)


# Filter large paths, dropping any parent of another large path


def filter_large(size_map, threshold_bytes, *, include_parents=False):
    """
    Filter paths with size >= threshold_bytes, dropping any path
    that has a descendant also in the filtered set.
    """
    candidates = {p for p, sz in size_map.items() if sz >= threshold_bytes}
    result = []
    for p in candidates:
        if not include_parents:
            # If we don't want parents, only keep paths that are not prefixes of others
            if any(q != p and q.startswith(p + os.sep) for q in candidates):
                continue
        result.append(p)
    return sorted(result)


@app.default()
def filter_by_size_only_children(
    minsize: str = "1G",
    *,
    print_size: bool = False,
    include_parents: bool = False,
):
    """
    Reads JSON from stdin, filters paths with size >= minsize,
    and prints them to stdout.

    Example usage:
        ```bash
        dust -j -D -d 99999999 | dust-filter 1M
        ```

    Args:
        show_parents: also print parent directories of large paths
    """
    try:
        threshold_bytes = parse_size(minsize)
    except Exception as e:
        print(f"Error parsing --minsize: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        data = json.load(sys.stdin)
    except Exception as e:
        print(f"Error reading JSON from stdin: {e}", file=sys.stderr)
        sys.exit(1)

    # Build size map
    size_map = {}
    traverse_dust_json(data, size_map)

    large_paths = filter_large(
        size_map, threshold_bytes, include_parents=include_parents
    )

    for path in large_paths:
        if print_size:
            size = size_map[path]
            print(f"{humanize.naturalsize(size, gnu=True):>9}  {path}")
        else:
            print(path)


if __name__ == "__main__":
    app()
