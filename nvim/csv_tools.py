# /// script
# requires-python = ">=3.11"
# dependencies = [
#    "polars",
#    "cyclopts",
#    "cwcwidth",
# ]
# ///

import io
import sys

import polars as pl
from cwcwidth import wcswidth
from cyclopts import App, Parameter

app = App(
    help_format="markdown",
    default_parameter=Parameter(
        consume_multiple=True,  # Allow list of arguments without repeating --option a --option b ..
        negative=False,  # Do not make --no-option as a boolean flag
    ),
    # version=__version__,
)


@app.command()
def align(
    in_path: str | None = None,
    filetype: str = "csv",
    out_separator=",",
    *,
    edit_mode: bool = False,
    fast: bool = False,
) -> None:
    """
    Align CSV columns for better readability.

    Args:
        edit_mode: If True, it will append quotes to all values, making it robust for editing.
        fast: If True, it will use character length for padding. If False, it will use character display width
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
    max_lengths: list[int]
    if fast:
        max_lengths = [
            max(df[col].str.len_chars().max(), len(col))  # pyright: ignore[reportArgumentType]
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
                col: col.ljust(max_length + 3)
                for col, max_length in zip(cols, max_lengths)
            }
        else:
            rename_map = {
                col: col.ljust(max_length + 1)
                for col, max_length in zip(cols, max_lengths)
            }

        df = df.rename(rename_map)
    else:
        # compute per-cell display-widths as extra columns
        df = df.with_columns(
            [
                pl.col(col)
                .map_elements(lambda s: wcswidth(s), return_dtype=pl.Int64)
                .alias(f"__disp_width_{col}")
                for col in cols
            ]
        )
        max_display_widths = {
            col: max(df[f"__disp_width_{col}"].max(), wcswidth(col))  # pyright: ignore[reportArgumentType]
            for col in cols
        }

        # target length is different per row
        df = df.with_columns(
            [
                (
                    max_display_widths[col]
                    - pl.col(f"__disp_width_{col}")
                    + pl.col(col).str.len_chars()
                    + 1
                ).alias(f"__target_len_{col}")
                for col in cols
            ]
        )

        # Pad columns so they align per column.
        df = df.with_columns(
            [
                pl.col(col).str.pad_end(length=pl.col(f"__target_len_{col}")).alias(col)
                for col in cols
            ]
        )

        # rename columns so they also align
        if edit_mode:
            # Add quotes to all values
            df = df.with_columns([('"' + pl.col(col) + '"').alias(col) for col in cols])

            rename_map = {
                col: col.ljust(max_display_widths[col] - wcswidth(col) + len(col) + 3)
                for col in cols
            }
        else:
            rename_map = {
                col: col.ljust(max_display_widths[col] - wcswidth(col) + len(col) + 1)
                for col in cols
            }

        df = df.rename(rename_map)

        # remove temporary columns
        df = df.drop([f"__disp_width_{col}" for col in cols])
        df = df.drop([f"__target_len_{col}" for col in cols])

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
