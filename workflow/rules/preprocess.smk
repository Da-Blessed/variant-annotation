rule prepare_reference:
    input:
        validated=VALIDATION_OK,
        fasta=input_reference_for,
    output:
        fasta=REFERENCE_FASTA,
        fai=REFERENCE_FAI,
    params:
        outdir=lambda wildcards, output: str(Path(output.fasta).parent),
        logdir=f"{LOG_DIR}/preprocess",
    resources:
        mem_mb=cfg_mem("vcf", 4096),
    log:
        f"{LOG_DIR}/preprocess/{{name}}.reference.log",
    conda:
        "../../envs/vg.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        ln -sfn "$(readlink -f {input.fasta:q})" {output.fasta:q}
        samtools faidx {output.fasta:q} > {log:q} 2>&1
        """


rule preprocess_vcf:
    input:
        vcf=DECONSTRUCTED_VCF,
        reference=REFERENCE_FASTA,
        fai=REFERENCE_FAI,
    output:
        vcf=PREPROCESSED_VCF,
        tbi=PREPROCESSED_TBI,
    params:
        outdir=lambda wildcards, output: str(Path(output.vcf).parent),
        tmpdir=lambda wildcards: f"{WORK_DIR}/tmp/bcftools/{wildcards.name}",
        logdir=f"{LOG_DIR}/preprocess",
    threads:
        cfg_threads("vcf", 4)
    resources:
        mem_mb=cfg_mem("vcf", 8192),
    log:
        f"{LOG_DIR}/preprocess/{{name}}.vcf.log",
    conda:
        "../../envs/vg.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.tmpdir:q} {params.logdir:q}
        bcftools norm \
            --threads {threads} \
            --check-ref e \
            --fasta-ref {input.reference:q} \
            --multiallelics -any \
            --output-type u \
            {input.vcf:q} 2> {log:q} \
          | bcftools sort \
                --temp-dir {params.tmpdir:q} \
                --output-type u 2>> {log:q} \
          | bcftools norm \
                --threads {threads} \
                --rm-dup exact \
                --output-type z \
                --output {output.vcf:q} 2>> {log:q}
        bcftools index \
            --threads {threads} \
            --tbi \
            --output {output.tbi:q} \
            {output.vcf:q} 2>> {log:q}
        """
