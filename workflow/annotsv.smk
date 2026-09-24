configfile: "../config/config.yaml"

include: "rules/common.smk"


rule all:
    input:
        expand(ANNOTSV_TSV, name=DATASETS),


include: "rules/normalize.smk"
include: "rules/annotsv.smk"
