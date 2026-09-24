#!/usr/bin/env python3
"""Validate a name/VCF manifest for the annotation workflow."""

from __future__ import annotations

import argparse
import csv
import gzip
import re
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, TextIO


SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$")


class ValidationError(RuntimeError):
    pass


@contextmanager
def open_text(path: Path) -> Iterator[TextIO]:
    with path.open("rb") as binary:
        compressed = binary.read(2) == b"\x1f\x8b"
    if compressed:
        with gzip.open(path, "rt") as handle:
            yield handle
    else:
        with path.open() as handle:
            yield handle


def validate_vcf(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValidationError(f"VCF does not exist or is empty: {path}")
    fileformat = False
    chrom_header = False
    with open_text(path) as handle:
        for line in handle:
            if line.startswith("##fileformat=VCF"):
                fileformat = True
            elif line.startswith("#CHROM\t"):
                chrom_header = True
                break
            elif not line.startswith("#"):
                break
    if not fileformat or not chrom_header:
        raise ValidationError(f"Not a valid VCF header: {path}")


def validate_manifest(path: Path) -> int:
    if not path.is_file():
        raise ValidationError(f"Input manifest does not exist: {path}")
    seen: set[str] = set()
    count = 0
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        if reader.fieldnames is None or not {"name", "vcf"}.issubset(reader.fieldnames):
            raise ValidationError("Manifest must contain tab-separated columns: name, vcf")
        for line_number, row in enumerate(reader, start=2):
            name = (row.get("name") or "").strip()
            vcf = (row.get("vcf") or "").strip()
            if not SAFE_NAME.fullmatch(name):
                raise ValidationError(f"Invalid dataset name at line {line_number}: {name!r}")
            if name in seen:
                raise ValidationError(f"Duplicate dataset name: {name}")
            if not vcf:
                raise ValidationError(f"Empty VCF path at line {line_number}")
            seen.add(name)
            validate_vcf(Path(vcf))
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
    except (OSError, UnicodeError, gzip.BadGzipFile, ValidationError) as error:
        parser.error(str(error))
    print(f"Validated {count} VCF dataset(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
