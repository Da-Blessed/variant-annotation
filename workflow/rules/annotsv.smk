rule annotsv_annotate:
    input:
        vcf=NORMALIZED_VCF,
        tbi=NORMALIZED_TBI,
    output:
        ANNOTSV_TSV,
    params:
        genome_build=ANNOTSV_GENOME_BUILD,
        annotations_dir=ANNOTSV_ANNOTATIONS_DIR,
        min_size=int(ANNOTSV_CONFIG.get("min_size", 50)),
        outdir=lambda wildcards, output: str(Path(output[0]).parent),
        logdir=f"{LOG_DIR}/annotsv",
    resources:
        mem_mb=cfg_mem("annotsv", 8192),
    log:
        f"{LOG_DIR}/annotsv/{{name}}.log",
    conda:
        "../../envs/annotsv.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        test -d {params.annotations_dir:q}
        AnnotSV \
            -SVinputFile {input.vcf:q} \
            -outputFile {output:q} \
            -genomeBuild {params.genome_build:q} \
            -annotationsDir {params.annotations_dir:q} \
            -annotationMode both \
            -SVinputInfo 1 \
            -SVminSize {params.min_size} \
            -overwrite 1 > {log:q} 2>&1
        """
