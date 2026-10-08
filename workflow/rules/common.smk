import csv
import re
from pathlib import Path


PROJECT_ROOT = Path(workflow.basedir).resolve()
if not (PROJECT_ROOT / "config").is_dir():
    PROJECT_ROOT = PROJECT_ROOT.parent


def required_config(key):
    value = config.get(key)
    if value is None or str(value).strip() == "":
        raise WorkflowError(f"Missing required configuration key: {key}")
    return str(value)


INPUTS_TSV = required_config("inputs")
OUTPUT_DIR = str(config.get("output_dir", "results")).rstrip("/")
WORK_DIR = str(config.get("work_dir", "work")).rstrip("/")
LOG_DIR = str(config.get("log_dir", "logs")).rstrip("/")
SNPEFF_CONFIG = config.get("snpeff", {})
ANNOTSV_CONFIG = config.get("annotsv", {})
SNPEFF_GENOME = str(SNPEFF_CONFIG.get("genome", "")).strip()
ANNOTSV_GENOME_BUILD = str(ANNOTSV_CONFIG.get("genome_build", "")).strip()
ANNOTSV_ANNOTATIONS_DIR = str(ANNOTSV_CONFIG.get("annotations_dir", "")).strip()
if not SNPEFF_GENOME:
    raise WorkflowError("Missing required configuration key: snpeff.genome")
if not ANNOTSV_GENOME_BUILD:
    raise WorkflowError("Missing required configuration key: annotsv.genome_build")
if not ANNOTSV_ANNOTATIONS_DIR:
    raise WorkflowError("Missing required configuration key: annotsv.annotations_dir")


def load_inputs(path):
    records = {}
    with open(path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        required = {
            "name",
            "gfa",
            "reference_fasta",
            "reference_sample",
            "reference_path",
            "reference_prefix",
        }
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise WorkflowError(
                f"{path} must contain tab-separated columns: "
                "name, gfa, reference_fasta, reference_sample, "
                "reference_path, reference_prefix"
            )
        for line_number, row in enumerate(reader, start=2):
            name = (row.get("name") or "").strip()
            gfa = (row.get("gfa") or "").strip()
            reference_fasta = (row.get("reference_fasta") or "").strip()
            reference_sample = (row.get("reference_sample") or "").strip()
            reference_path = (row.get("reference_path") or "").strip()
            reference_prefix = (row.get("reference_prefix") or "").strip()
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name):
                raise WorkflowError(f"Unsafe dataset name at {path}:{line_number}: {name!r}")
            if not gfa:
                raise WorkflowError(f"Empty GFA path at {path}:{line_number}")
            if not reference_fasta:
                raise WorkflowError(f"Empty reference FASTA path at {path}:{line_number}")
            if not reference_sample:
                raise WorkflowError(f"Empty reference sample at {path}:{line_number}")
            if bool(reference_path) == bool(reference_prefix):
                raise WorkflowError(
                    f"Set exactly one of reference_path or reference_prefix "
                    f"at {path}:{line_number}"
                )
            if name in records:
                raise WorkflowError(f"Duplicate dataset name '{name}' in {path}")
            records[name] = {
                "gfa": gfa,
                "reference_fasta": reference_fasta,
                "reference_sample": reference_sample,
                "reference_path": reference_path,
                "reference_prefix": reference_prefix,
            }
    if not records:
        raise WorkflowError(f"No datasets found in {path}")
    return records


INPUT_RECORDS = load_inputs(INPUTS_TSV)
DATASETS = list(INPUT_RECORDS)


def record_value(wildcards, key):
    return INPUT_RECORDS[wildcards.name][key]


def input_gfa_for(wildcards):
    return record_value(wildcards, "gfa")


def input_reference_for(wildcards):
    return record_value(wildcards, "reference_fasta")


def reference_sample_for(wildcards):
    return record_value(wildcards, "reference_sample")


def deconstruct_selector_flag(wildcards):
    if record_value(wildcards, "reference_path"):
        return "--path"
    return "--path-prefix"


def deconstruct_selector_value(wildcards):
    return (
        record_value(wildcards, "reference_path")
        or record_value(wildcards, "reference_prefix")
    )


def cfg_threads(name, default):
    return max(1, int(config.get("threads", {}).get(name, default)))


def cfg_mem(name, default):
    return max(1, int(config.get("resources", {}).get(name, default)))


VALIDATION_OK = f"{WORK_DIR}/validation/inputs.ok"
GBZ_GRAPH = f"{WORK_DIR}/graph/{{name}}.gbz"
DECONSTRUCTED_VCF = f"{WORK_DIR}/deconstructed/{{name}}.vcf"
REFERENCE_FASTA = f"{WORK_DIR}/reference/{{name}}.fa"
REFERENCE_FAI = f"{WORK_DIR}/reference/{{name}}.fa.fai"
PREPROCESSED_VCF = f"{OUTPUT_DIR}/{{name}}/{{name}}.preprocessed.vcf.gz"
PREPROCESSED_TBI = f"{OUTPUT_DIR}/{{name}}/{{name}}.preprocessed.vcf.gz.tbi"
SNPEFF_DATA_DIR = str(SNPEFF_CONFIG.get("data_dir", f"{WORK_DIR}/snpeff/data"))
SNPEFF_DATABASE_OK = f"{WORK_DIR}/snpeff/{SNPEFF_GENOME}.ready"
SNPEFF_VCF = f"{OUTPUT_DIR}/{{name}}/{{name}}.snpeff.vcf.gz"
SNPEFF_TBI = f"{OUTPUT_DIR}/{{name}}/{{name}}.snpeff.vcf.gz.tbi"
ANNOTSV_TSV = f"{OUTPUT_DIR}/{{name}}/{{name}}.annotsv.tsv"
