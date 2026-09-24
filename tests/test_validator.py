from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "validate_manifest.py"


class ManifestValidatorTests(unittest.TestCase):
    def test_valid_manifest(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--inputs", "tests/data/inputs.tsv"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Validated 1 VCF", result.stdout)

    def test_duplicate_name_is_rejected(self) -> None:
        vcf = ROOT / "tests/data/input.vcf"
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "inputs.tsv"
            manifest.write_text(f"name\tvcf\ndup\t{vcf}\ndup\t{vcf}\n")
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), "--inputs", str(manifest)],
                cwd=ROOT,
                text=True,
                capture_output=True,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Duplicate dataset name", result.stderr)


if __name__ == "__main__":
    unittest.main()
