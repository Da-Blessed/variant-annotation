configfile: "../config/config.yaml"

include: "rules/common.smk"


rule all:
    input:
        expand(SNPEFF_VCF, name=DATASETS),
        expand(SNPEFF_TBI, name=DATASETS),


include: "rules/normalize.smk"
include: "rules/snpeff.smk"
