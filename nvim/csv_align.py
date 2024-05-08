import argparse
import io
import sys

import polars as pl


def main():
    parser = argparse.ArgumentParser(
        description="Align CSV columns for better readability. Ignore quotes."
    )
    parser.add_argument(
        "--type",
        help="Type of separator",
        choices=["csv", "tsv"],
        default="csv",
    )
    parser.add_argument(
        "--csv_file",
        help="Path to CSV file",
        type=str,
        default=None,
    )

    args = parser.parse_args()

    if args.type == "csv":
        separator = ","
    elif args.type == "tsv":
        separator = "\t"
    else:
        raise ValueError(f"Unknown type: {args.type}")

    # Read CSV from stdin and all columns as strings (without type inference)

    if args.csv_file and args.csv_file != "-":
        csv_file = args.csv_file
    else:
        csv_file = io.StringIO(sys.stdin.read())
    df = pl.read_csv(csv_file, separator=separator, infer_schema_length=0)
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

    df.write_csv(file=sys.stdout, quote_style="never")


if __name__ == "__main__":
    main()
