configfile: "../config/config.yaml"

include: "rules/common.smk"


rule all:
    input:
        expand(PREPROCESSED_VCF, name=DATASETS),
        expand(PREPROCESSED_TBI, name=DATASETS),
        expand(ANNOTSV_TSV, name=DATASETS),


include: "rules/deconstruct.smk"
include: "rules/preprocess.smk"
include: "rules/annotsv.smk"
