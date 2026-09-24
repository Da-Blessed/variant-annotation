configfile: "config/config.yaml"

include: "workflow/rules/common.smk"


rule all:
    input:
        expand(SNPEFF_VCF, name=DATASETS),
        expand(SNPEFF_TBI, name=DATASETS),
        expand(ANNOTSV_TSV, name=DATASETS),


include: "workflow/rules/normalize.smk"
include: "workflow/rules/snpeff.smk"
include: "workflow/rules/annotsv.smk"
