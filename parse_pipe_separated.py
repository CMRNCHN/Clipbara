#!/usr/bin/env python3
"""
Parse pipe-separated files where the first line contains keys
and subsequent lines contain values.

Usage:
    python parse_pipe_separated.py input.txt [--format json|csv|table]
"""

import sys
import json
import csv
import glob
from pathlib import Path
from typing import List, Dict, Optional


def parse_pipe_separated(file_path: str, separator: str = "|") -> List[Dict[str, str]]:
    """
    Parse a pipe-separated file and return list of dictionaries.

    Args:
        file_path: Path to the input file
        separator: The delimiter character (default: |)

    Returns:
        List of dictionaries mapping keys to values
    """
    records = []

    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if not lines:
        return records

    # Parse header (first line)
    keys = [k.strip() for k in lines[0].strip().split(separator)]

    # Parse data rows
    for line in lines[1:]:
        stripped = line.strip()
        if not stripped:  # Skip empty lines
            continue

        values = [v.strip() for v in stripped.split(separator)]

        # Handle mismatched column counts
        if len(values) != len(keys):
            print(f"Warning: Row has {len(values)} values but header has {len(keys)} keys",
                  file=sys.stderr)
            # Pad with empty strings or truncate
            while len(values) < len(keys):
                values.append("")
            values = values[:len(keys)]

        record = dict(zip(keys, values))
        records.append(record)

    return records


def output_json(records: List[Dict[str, str]]) -> str:
    """Format records as JSON."""
    return json.dumps(records, indent=2, ensure_ascii=False)


def output_csv(records: List[Dict[str, str]]) -> str:
    """Format records as CSV."""
    if not records:
        return ""

    # Collect all unique fieldnames from all records
    all_fields = []
    seen = set()
    for record in records:
        for key in record.keys():
            if key not in seen:
                all_fields.append(key)
                seen.add(key)

    # Collect output
    import io
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=all_fields, restval="")
    writer.writeheader()
    writer.writerows(records)

    return buffer.getvalue()


def output_table(records: List[Dict[str, str]]) -> str:
    """Format records as a simple ASCII table."""
    if not records:
        return ""

    keys = records[0].keys()
    col_widths = {key: len(key) for key in keys}

    # Calculate column widths
    for record in records:
        for key in keys:
            col_widths[key] = max(col_widths[key], len(str(record.get(key, ""))))

    # Build table
    lines = []
    header = " | ".join(key.ljust(col_widths[key]) for key in keys)
    lines.append(header)
    lines.append("-" * len(header))

    for record in records:
        row = " | ".join(str(record.get(key, "")).ljust(col_widths[key]) for key in keys)
        lines.append(row)

    return "\n".join(lines)


def scan_folder(folder_path: str, pattern: str = "*.txt") -> List[str]:
    """
    Scan a folder for files matching the pattern.

    Args:
        folder_path: Path to the folder
        pattern: Glob pattern for files (default: *.txt)

    Returns:
        List of file paths found
    """
    folder = Path(folder_path)
    if not folder.is_dir():
        raise ValueError(f"'{folder_path}' is not a directory")

    # Find all matching files
    files = sorted(folder.glob(pattern))
    return [str(f) for f in files if f.is_file()]


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_pipe_separated.py [OPTIONS]")
        print("\nOptions:")
        print("  <file1> [<file2> ...]     Parse specific files")
        print("  --folder <path>           Auto-import all .txt files from folder")
        print("  --folder <path> --pattern *.csv   Import with custom pattern")
        print("  --format json|csv|table   Output format (default: table)")
        print("\nExamples:")
        print("  python parse_pipe_separated.py file1.txt file2.txt")
        print("  python parse_pipe_separated.py --folder /path/to/data")
        print("  python parse_pipe_separated.py --folder /path/to/data --format csv > combined.csv")
        print("  python parse_pipe_separated.py --folder . --pattern '*.txt' --format table")
        sys.exit(1)

    # Parse arguments
    input_files = []
    output_format = "table"
    folder_path = None
    pattern = "*.txt"

    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]

        if arg == "--format" and i + 1 < len(sys.argv):
            output_format = sys.argv[i + 1]
            i += 2
        elif arg == "--folder" and i + 1 < len(sys.argv):
            folder_path = sys.argv[i + 1]
            i += 2
        elif arg == "--pattern" and i + 1 < len(sys.argv):
            pattern = sys.argv[i + 1]
            i += 2
        elif arg.startswith("--"):
            i += 1  # Skip unknown flags
        else:
            input_files.append(arg)
            i += 1

    # Get files from folder if specified
    if folder_path:
        try:
            input_files.extend(scan_folder(folder_path, pattern))
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)

    if not input_files:
        print("Error: No input files specified or found in folder", file=sys.stderr)
        sys.exit(1)

    # Parse all files
    all_records = []
    for input_file in input_files:
        try:
            records = parse_pipe_separated(input_file)
            all_records.extend(records)
            print(f"Loaded {len(records)} records from {input_file}", file=sys.stderr)
        except FileNotFoundError:
            print(f"Warning: File '{input_file}' not found", file=sys.stderr)
        except Exception as e:
            print(f"Warning: Error parsing '{input_file}': {e}", file=sys.stderr)

    if not all_records:
        print("Error: No records parsed from any files", file=sys.stderr)
        sys.exit(1)

    print(f"Total: {len(all_records)} records", file=sys.stderr)

    # Output in requested format
    if output_format == "json":
        print(output_json(all_records))
    elif output_format == "csv":
        print(output_csv(all_records).rstrip())
    elif output_format == "table":
        print(output_table(all_records))
    else:
        print(f"Unknown format: {output_format}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
