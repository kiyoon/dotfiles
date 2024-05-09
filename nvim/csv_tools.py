import io
import sys
from typing import Optional

import polars as pl
import typer

app = typer.Typer(context_settings={"help_option_names": ["-h", "--help"]})


@app.command()
def align(
    in_path: Optional[str] = None, filetype: str = "csv", out_separator=","
) -> None:
    """
    Align CSV columns for better readability. Ignore quotes.
    """
    if filetype == "csv":
        in_separator = ","
    elif filetype == "tsv":
        in_separator = "\t"
    else:
        raise ValueError(f"Unknown type: {filetype}")

    # Read CSV from stdin and all columns as strings (without type inference)

    if in_path and in_path != "-":
        csv_file = in_path
    else:
        csv_file = io.StringIO(sys.stdin.read())
    df = pl.read_csv(csv_file, separator=in_separator, infer_schema_length=0)
    df = df.fill_null("")

    # Pad columns so they align per column.

    # Get the max length of each column
    cols = df.columns
    max_lengths: list[int] = [
        max(df[col].str.len_chars().max(), len(col))  # type: ignore
        for col in cols
    ]
    # print(max_lengths)

    df = df.with_columns(
        [
            pl.col(col).str.pad_end(length=max_length + 1).alias(col)
            for col, max_length in zip(cols, max_lengths)
        ]
    )

    rename_map = {
        col: col.ljust(max_length + 1) for col, max_length in zip(cols, max_lengths)
    }
    df = df.rename(rename_map)

    df.write_csv(file=sys.stdout, quote_style="never", separator=out_separator)


@app.command()
def select(
    comma_separated_columns: str,
    in_path: Optional[str] = None,
    filetype: str = "csv",
    out_separator=",",
) -> None:
    """
    Select columns from CSV.
    """
    if filetype == "csv":
        in_separator = ","
    elif filetype == "tsv":
        in_separator = "\t"
    else:
        raise ValueError(f"Unknown type: {filetype}")

    # Read CSV from stdin and all columns as strings (without type inference)

    if in_path and in_path != "-":
        csv_file = in_path
    else:
        csv_file = io.StringIO(sys.stdin.read())

    columns = comma_separated_columns.split(",")
    df = pl.read_csv(
        csv_file, separator=in_separator, infer_schema_length=0, columns=columns
    )
    df.write_csv(file=sys.stdout, separator=out_separator)


if __name__ == "__main__":
    app()
