# ruff: noqa: UP007
import io
import subprocess
import sys
from typing import Optional

# import tree_sitter_python as tspython
import typer

# from tree_sitter import Language, Parser

# PY_LANGUAGE = Language(tspython.language())

app = typer.Typer(context_settings={"help_option_names": ["-h", "--help"]})


@app.command()
def find_python_import_in_project(
    project_root: str,
    module_name: str,
) -> None:
    # parser = Parser(PY_LANGUAGE)
    # tree = parser.parse(bytes("import " + module_name, "utf8"))
    # print(tree.root_node)
    rg_outputs = subprocess.run(
        ["fd", "-e", "py", "-x", "rg", "--json", module_name],
        cwd=project_root,
        capture_output=True,
    )
    print(rg_outputs)

    for line in rg_outputs.stdout.decode("utf-8").split("\n"):
        print(line)
        # if line:
        #     print(line)
        #     print(line["data"]["path"])


if __name__ == "__main__":
    # app()
    find_python_import_in_project("/Users/kiyoon/project/dti-db-curation", "logging")
