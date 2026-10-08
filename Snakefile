configfile: "config/config.yaml"

include: "workflow/rules/common.smk"


rule all:
    input:
        expand(PREPROCESSED_VCF, name=DATASETS),
        expand(PREPROCESSED_TBI, name=DATASETS),
        expand(SNPEFF_VCF, name=DATASETS),
        expand(SNPEFF_TBI, name=DATASETS),
        expand(ANNOTSV_TSV, name=DATASETS),


include: "workflow/rules/deconstruct.smk"
include: "workflow/rules/preprocess.smk"
include: "workflow/rules/snpeff.smk"
include: "workflow/rules/annotsv.smk"
