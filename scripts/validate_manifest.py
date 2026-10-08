#!/usr/bin/env python3
"""Validate GFA inputs and reference FASTA files for the annotation workflow."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")
REQUIRED_COLUMNS = {
    "name",
    "gfa",
    "reference_fasta",
    "reference_sample",
    "reference_path",
    "reference_prefix",
}


class ValidationError(RuntimeError):
    pass


def require_plain_file(path: Path, label: str) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValidationError(f"{label} does not exist or is empty: {path}")
    with path.open("rb") as handle:
        if handle.read(2) == b"\x1f\x8b":
            raise ValidationError(f"{label} must be uncompressed: {path}")


def validate_gfa(path: Path) -> None:
    require_plain_file(path, "GFA")
    has_segment = False
    has_path = False
    with path.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            record_type = fields[0]
            if record_type == "S":
                if len(fields) < 3:
                    raise ValidationError(f"Malformed GFA S-line at {path}:{line_number}")
                has_segment = True
            elif record_type == "P":
                if len(fields) < 4:
                    raise ValidationError(f"Malformed GFA P-line at {path}:{line_number}")
                has_path = True
            elif record_type == "W":
                if len(fields) < 7:
                    raise ValidationError(f"Malformed GFA W-line at {path}:{line_number}")
                has_path = True
    if not has_segment:
        raise ValidationError(f"GFA contains no segment (S) records: {path}")
    if not has_path:
        raise ValidationError(f"GFA contains no path or walk (P/W) records: {path}")


def validate_fasta(path: Path) -> None:
    require_plain_file(path, "Reference FASTA")
    sequence_names: set[str] = set()
    current_name = ""
    has_sequence = False
    with path.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            if stripped.startswith(">"):
                current_name = stripped[1:].split(maxsplit=1)[0]
                if not current_name:
                    raise ValidationError(f"Empty FASTA header at {path}:{line_number}")
                if current_name in sequence_names:
                    raise ValidationError(f"Duplicate FASTA sequence name: {current_name}")
                sequence_names.add(current_name)
            else:
                if not current_name:
                    raise ValidationError(
                        f"FASTA sequence occurs before the first header at {path}:{line_number}"
                    )
                has_sequence = True
    if not sequence_names or not has_sequence:
        raise ValidationError(f"Reference FASTA contains no sequence: {path}")


def validate_manifest(path: Path) -> int:
    if not path.is_file():
        raise ValidationError(f"Input manifest does not exist: {path}")
    seen: set[str] = set()
    count = 0
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None or not REQUIRED_COLUMNS.issubset(reader.fieldnames):
            columns = ", ".join(sorted(REQUIRED_COLUMNS))
            raise ValidationError(f"Manifest must contain tab-separated columns: {columns}")
        for line_number, row in enumerate(reader, start=2):
            name = (row.get("name") or "").strip()
            gfa = (row.get("gfa") or "").strip()
            reference_fasta = (row.get("reference_fasta") or "").strip()
            reference_sample = (row.get("reference_sample") or "").strip()
            reference_path = (row.get("reference_path") or "").strip()
            reference_prefix = (row.get("reference_prefix") or "").strip()
            if not SAFE_NAME.fullmatch(name):
                raise ValidationError(f"Invalid dataset name at line {line_number}: {name!r}")
            if name in seen:
                raise ValidationError(f"Duplicate dataset name: {name}")
            if not gfa:
                raise ValidationError(f"Empty GFA path at line {line_number}")
            if not reference_fasta:
                raise ValidationError(f"Empty reference FASTA path at line {line_number}")
            if not reference_sample:
                raise ValidationError(f"Empty reference sample at line {line_number}")
            if bool(reference_path) == bool(reference_prefix):
                raise ValidationError(
                    "Set exactly one of reference_path or reference_prefix "
                    f"at line {line_number}"
                )
            seen.add(name)
            validate_gfa(Path(gfa))
            validate_fasta(Path(reference_fasta))
            count += 1
    if count == 0:
        raise ValidationError("Manifest contains no datasets")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", required=True, type=Path)
    args = parser.parse_args()
    try:
        count = validate_manifest(args.inputs)
    except (OSError, UnicodeError, ValidationError) as error:
        parser.error(str(error))
    print(f"Validated {count} GFA dataset(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
