rule validate_inputs:
    input:
        manifest=INPUTS_TSV,
        vcfs=lambda wildcards: list(INPUT_RECORDS.values()),
    output:
        touch(VALIDATION_OK),
    params:
        script=str(PROJECT_ROOT / "scripts" / "validate_manifest.py"),
        outdir=lambda wildcards, output: str(Path(output[0]).parent),
        logdir=f"{LOG_DIR}/validation",
    resources:
        mem_mb=cfg_mem("validation", 1024),
    log:
        f"{LOG_DIR}/validation/inputs.log",
    conda:
        "../../envs/common.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        python {params.script:q} --inputs {input.manifest:q} > {log:q} 2>&1
        """


rule normalize_vcf:
    input:
        validated=VALIDATION_OK,
        vcf=input_vcf_for,
    output:
        vcf=NORMALIZED_VCF,
        tbi=NORMALIZED_TBI,
    params:
        outdir=lambda wildcards, output: str(Path(output.vcf).parent),
        logdir=f"{LOG_DIR}/normalize",
    threads:
        cfg_threads("vcf", 2)
    resources:
        mem_mb=cfg_mem("vcf", 2048),
    log:
        f"{LOG_DIR}/normalize/{{name}}.log",
    conda:
        "../../envs/common.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        bcftools view --threads {threads} -Oz -o {output.vcf:q} {input.vcf:q} 2> {log:q}
        bcftools index --threads {threads} --tbi -o {output.tbi:q} {output.vcf:q} 2>> {log:q}
        """
