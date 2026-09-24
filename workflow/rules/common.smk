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
        required = {"name", "vcf"}
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise WorkflowError(f"{path} must contain tab-separated columns: name, vcf")
        for line_number, row in enumerate(reader, start=2):
            name = (row.get("name") or "").strip()
            vcf = (row.get("vcf") or "").strip()
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", name):
                raise WorkflowError(f"Unsafe dataset name at {path}:{line_number}: {name!r}")
            if not vcf:
                raise WorkflowError(f"Empty VCF path at {path}:{line_number}")
            if name in records:
                raise WorkflowError(f"Duplicate dataset name '{name}' in {path}")
            records[name] = vcf
    if not records:
        raise WorkflowError(f"No datasets found in {path}")
    return records


INPUT_RECORDS = load_inputs(INPUTS_TSV)
DATASETS = list(INPUT_RECORDS)


def input_vcf_for(wildcards):
    return INPUT_RECORDS[wildcards.name]


def cfg_threads(name, default):
    return max(1, int(config.get("threads", {}).get(name, default)))


def cfg_mem(name, default):
    return max(1, int(config.get("resources", {}).get(name, default)))


VALIDATION_OK = f"{WORK_DIR}/validation/inputs.ok"
NORMALIZED_VCF = f"{WORK_DIR}/normalized/{{name}}.vcf.gz"
NORMALIZED_TBI = f"{WORK_DIR}/normalized/{{name}}.vcf.gz.tbi"
SNPEFF_DATA_DIR = str(SNPEFF_CONFIG.get("data_dir", f"{WORK_DIR}/snpeff/data"))
SNPEFF_DATABASE_OK = f"{WORK_DIR}/snpeff/{SNPEFF_GENOME}.ready"
SNPEFF_VCF = f"{OUTPUT_DIR}/{{name}}/{{name}}.snpeff.vcf.gz"
SNPEFF_TBI = f"{OUTPUT_DIR}/{{name}}/{{name}}.snpeff.vcf.gz.tbi"
ANNOTSV_TSV = f"{OUTPUT_DIR}/{{name}}/{{name}}.annotsv.tsv"
