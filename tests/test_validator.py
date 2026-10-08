from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "validate_manifest.py"
GFA = ROOT / "tests/data/graph.gfa"
REFERENCE = ROOT / "tests/data/reference.fa"


def run_validator(manifest: Path | str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), "--inputs", str(manifest)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class ManifestValidatorTests(unittest.TestCase):
    def test_valid_manifest(self) -> None:
        result = run_validator("tests/data/inputs.tsv")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Validated 1 GFA", result.stdout)

    def test_duplicate_name_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "inputs.tsv"
            manifest.write_text(
                "name\tgfa\treference_fasta\treference_sample\t"
                "reference_path\treference_prefix\n"
                f"dup\t{GFA}\t{REFERENCE}\tref\tref#0#chr1\t\n"
                f"dup\t{GFA}\t{REFERENCE}\tref\tref#0#chr1\t\n"
            )
            result = run_validator(manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Duplicate dataset name", result.stderr)

    def test_exactly_one_reference_selector_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "inputs.tsv"
            manifest.write_text(
                "name\tgfa\treference_fasta\treference_sample\t"
                "reference_path\treference_prefix\n"
                f"test\t{GFA}\t{REFERENCE}\tref\tref#0#chr1\tref#0#\n"
            )
            result = run_validator(manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly one", result.stderr)

    def test_gfa_requires_a_path_or_walk(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            gfa = temporary / "graph.gfa"
            gfa.write_text("H\tVN:Z:1.0\nS\t1\tA\n")
            manifest = temporary / "inputs.tsv"
            manifest.write_text(
                "name\tgfa\treference_fasta\treference_sample\t"
                "reference_path\treference_prefix\n"
                f"test\t{gfa}\t{REFERENCE}\tref\tref#0#chr1\t\n"
            )
            result = run_validator(manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no path or walk", result.stderr)


if __name__ == "__main__":
    unittest.main()
