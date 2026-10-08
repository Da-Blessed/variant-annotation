rule snpeff_prepare_database:
    output:
        touch(SNPEFF_DATABASE_OK),
    params:
        genome=SNPEFF_GENOME,
        data_dir=SNPEFF_DATA_DIR,
        download=bool(SNPEFF_CONFIG.get("download_database", True)),
        outdir=lambda wildcards, output: str(Path(output[0]).parent),
        logdir=f"{LOG_DIR}/snpeff",
    resources:
        mem_mb=cfg_mem("snpeff", 8192),
    log:
        f"{LOG_DIR}/snpeff/database.log",
    conda:
        "../../envs/snpeff.yaml"
    run:
        from snakemake.shell import shell

        shell("mkdir -p {params.outdir:q} {params.logdir:q} {params.data_dir:q}")
        if params.download:
            shell(
                "snpEff download -noLog -dataDir {params.data_dir:q} "
                "{params.genome:q} > {log:q} 2>&1"
            )
        shell(
            "test -s {params.data_dir:q}/{params.genome:q}/snpEffectPredictor.bin "
            "2>> {log:q}"
        )


rule snpeff_annotate:
    input:
        vcf=PREPROCESSED_VCF,
        tbi=PREPROCESSED_TBI,
        database=SNPEFF_DATABASE_OK,
    output:
        vcf=SNPEFF_VCF,
        tbi=SNPEFF_TBI,
    params:
        genome=SNPEFF_GENOME,
        data_dir=SNPEFF_DATA_DIR,
        outdir=lambda wildcards, output: str(Path(output.vcf).parent),
        logdir=f"{LOG_DIR}/snpeff",
    threads:
        cfg_threads("vcf", 2)
    resources:
        mem_mb=cfg_mem("snpeff", 8192),
    log:
        f"{LOG_DIR}/snpeff/{{name}}.log",
    conda:
        "../../envs/snpeff.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        export JAVA_TOOL_OPTIONS="-Xmx{resources.mem_mb}m"
        snpEff ann -noLog -noStats -nodownload \
            -dataDir {params.data_dir:q} \
            {params.genome:q} {input.vcf:q} 2> {log:q} \
          | bgzip --threads {threads} -c > {output.vcf:q}
        bcftools index --threads {threads} --tbi \
            -o {output.tbi:q} {output.vcf:q} 2>> {log:q}
        """
