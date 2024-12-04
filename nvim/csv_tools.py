import io
import sys

import polars as pl
import typer

app = typer.Typer(context_settings={"help_option_names": ["-h", "--help"]})


@app.command()
def align(
    in_path: str | None = None,
    filetype: str = "csv",
    out_separator=",",
    edit_mode: bool = False,
) -> None:
    """
    Align CSV columns for better readability.

    Args:
        edit_mode: If True, it will append quotes to all values, making it robust for editing.
    """
    if filetype == "csv":
        in_separator = ","
    elif filetype == "tsv":
        in_separator = "\t"
    else:
        raise ValueError(f"Unknown type: {filetype}")

    if in_path and in_path != "-":
        csv_file = in_path
    else:
        csv_file = io.StringIO(sys.stdin.read())

    # Read all columns as strings (without type inference)
    df = pl.read_csv(csv_file, separator=in_separator, infer_schema_length=0)
    df = df.fill_null("")

    cols = df.columns

    if edit_mode:
        # Replace " with ""
        df = df.with_columns(
            [pl.col(col).str.replace_all('"', '""').alias(col) for col in cols]
        )

    # Get the max length of each column
    max_lengths: list[int] = [
        max(df[col].str.len_chars().max(), len(col))  # type: ignore
        for col in cols
    ]

    # Pad columns so they align per column.
    df = df.with_columns(
        [
            pl.col(col).str.pad_end(length=max_length + 1).alias(col)
            for col, max_length in zip(cols, max_lengths)
        ]
    )

    if edit_mode:
        # Add quotes to all values
        df = df.with_columns([('"' + pl.col(col) + '"').alias(col) for col in cols])

        rename_map = {
            col: col.ljust(max_length + 3) for col, max_length in zip(cols, max_lengths)
        }
    else:
        rename_map = {
            col: col.ljust(max_length + 1) for col, max_length in zip(cols, max_lengths)
        }

    df = df.rename(rename_map)

    df.write_csv(file=sys.stdout, quote_style="never", separator=out_separator)


@app.command()
def shrink(
    in_path: str | None = None,
    filetype: str = "csv",
    out_separator=",",
) -> None:
    """
    Shrink aligned columns from CSV. Works only when align(edit_mode=True) was used.
    """
    if filetype == "csv":
        in_separator = ","
    elif filetype == "tsv":
        in_separator = "\t"
    else:
        raise ValueError(f"Unknown type: {filetype}")

    if in_path and in_path != "-":
        csv_file = in_path
    else:
        csv_file = io.StringIO(sys.stdin.read())

    # Read all columns as strings (without type inference)
    df = pl.read_csv(csv_file, separator=in_separator, infer_schema_length=0)

    # Remove padded spaces
    cols = df.columns
    df = df.with_columns([pl.col(col).str.strip_chars().alias(col) for col in cols])
    rename_map = {col: col.strip() for col in cols}
    df = df.rename(rename_map)

    # print the result
    df.write_csv(file=sys.stdout, separator=out_separator)


@app.command()
def select(
    comma_separated_columns: str,
    in_path: str | None = None,
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

    if in_path and in_path != "-":
        csv_file = in_path
    else:
        csv_file = io.StringIO(sys.stdin.read())

    columns = comma_separated_columns.split(",")
    # Read all columns as strings (without type inference)
    df = pl.read_csv(
        csv_file, separator=in_separator, infer_schema_length=0, columns=columns
    )
    df.write_csv(file=sys.stdout, separator=out_separator)


if __name__ == "__main__":
    app()
