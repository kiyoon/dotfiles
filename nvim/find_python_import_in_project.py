# ruff: noqa: UP007
import io
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

import tree_sitter
import tree_sitter_python as tspython
import typer
from tree_sitter import Language, Parser

PY_LANGUAGE = Language(tspython.language())

app = typer.Typer(context_settings={"help_option_names": ["-h", "--help"]})


def _get_node(tree: tree_sitter.Tree, row, col):
    named_node = tree.root_node.named_descendant_for_point_range((row, col), (row, col))
    # named_node = tree.root_node.descendant_for_point_range((row, col), (row, col))
    return named_node


@app.command()
def find_python_import_in_project(
    project_root: str,
    module_name: str,
) -> None:
    parser = Parser(PY_LANGUAGE)
    tree = parser.parse(bytes("import " + module_name, "utf8"))
    print(tree.root_node)
    # NOTE: rg json outputs are (1, 0)-indexed
    rg_outputs = subprocess.run(
        ["fd", "-e", "py", "-x", "rg", "--json", module_name],
        cwd=project_root,
        capture_output=True,
    )
    print(rg_outputs)

    # 0-indexed row, col
    file_path_to_rowcol: dict[str, list[tuple[int, int, int]]] = defaultdict(list)
    for line in rg_outputs.stdout.decode("utf-8").split("\n"):
        if not line:
            continue
        print(line)
        rg_output = json.loads(line)
        print(rg_output["type"])
        if rg_output["type"] == "match":
            file_path = str(
                (Path(project_root) / rg_output["data"]["path"]["text"]).resolve()
            )
            row = rg_output["data"]["line_number"] - 1
            col = rg_output["data"]["submatches"][0]["start"]
            col_end = rg_output["data"]["submatches"][0]["end"]
            file_path_to_rowcol[file_path].append((row, col, col_end))

    print(file_path_to_rowcol)

    for file_path, rowcols in file_path_to_rowcol.items():
        with open(file_path) as f:
            lines: str = f.read()

        tree = parser.parse(bytes(lines, "utf8"))

        # tree.root_node_with_offset(
        # get node at position

        # import .. as ..
        #
        # (import_statement ; [15, 0] - [15, 18]
        #   name: (aliased_import ; [15, 7] - [15, 18]
        #     name: (dotted_name ; [15, 7] - [15, 12]
        #       (identifier)) ; [15, 7] - [15, 12]
        #     alias: (identifier))) ; [15, 16] - [15, 18]
        #
        # from .. import .. as ..
        #
        # (import_from_statement ; [2, 0] - [7, 1]
        #   module_name: (dotted_name ; [2, 5] - [2, 40]
        #     (identifier) ; [2, 5] - [2, 20]
        #     (identifier) ; [2, 21] - [2, 27]
        #     (identifier) ; [2, 28] - [2, 31]
        #     (identifier)) ; [2, 32] - [2, 40]
        #   name: (dotted_name ; [3, 4] - [3, 25]
        #     (identifier)) ; [3, 4] - [3, 25]
        #   name: (dotted_name ; [4, 4] - [4, 30]
        #     (identifier)) ; [4, 4] - [4, 30]
        #   name: (dotted_name ; [5, 4] - [5, 17]
        #     (identifier)) ; [5, 4] - [5, 17]
        #   name: (aliased_import ; [6, 4] - [6, 32]
        #     name: (dotted_name ; [6, 4] - [6, 25]
        #       (identifier)) ; [6, 4] - [6, 25]
        #     alias: (identifier))) ; [6, 29] - [6, 32]

        # query = PY_LANGUAGE.query("""
        #     (import_statement name: (dotted_name) @import)
        #     (import_statement name: (aliased_import alias: (identifier) @import_as))
        #     (import_from_statement name: (dotted_name) @from_import)
        #     (import_from_statement name: (aliased_import alias: (identifier) @from_import_as))
        #     """)

        for row_col_colend in rowcols:
            # match = query.matches(
            #     tree.root_node,
            #     start_point=(row_col_colend[0], row_col_colend[1]),
            #     end_point=(row_col_colend[0], row_col_colend[1]),
            # )
            # print(match)

            node = _get_node(tree, row_col_colend[0], row_col_colend[1])
            if node is None or node.type != "identifier":
                continue

            print(node)
            print(node.type)
            print(node.parent)


if __name__ == "__main__":
    # app()
    find_python_import_in_project("/home/kiyoon/project/dti-db-curation", "abcd")
    # find_python_import_in_project("/Users/kiyoon/project/dti-db-curation", "logging")
