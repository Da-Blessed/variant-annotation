rule validate_inputs:
    input:
        manifest=INPUTS_TSV,
        files=lambda wildcards: [
            value
            for record in INPUT_RECORDS.values()
            for value in (record["gfa"], record["reference_fasta"])
        ],
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


rule build_gbz:
    input:
        validated=VALIDATION_OK,
        gfa=input_gfa_for,
    output:
        GBZ_GRAPH,
    params:
        reference_sample=reference_sample_for,
        outdir=lambda wildcards, output: str(Path(output[0]).parent),
        tmpdir=lambda wildcards: f"{WORK_DIR}/tmp/gbwt/{wildcards.name}",
        logdir=f"{LOG_DIR}/deconstruct",
    threads:
        cfg_threads("graph", 8)
    resources:
        mem_mb=cfg_mem("graph", 32768),
    log:
        f"{LOG_DIR}/deconstruct/{{name}}.gbwt.log",
    conda:
        "../../envs/vg.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.tmpdir:q} {params.logdir:q}
        vg gbwt \
            --gfa-input \
            --set-reference {params.reference_sample:q} \
            --gbz-format \
            --graph-name {output:q} \
            --num-jobs {threads} \
            --temp-dir {params.tmpdir:q} \
            {input.gfa:q} > {log:q} 2>&1
        test -s {output:q}
        """


rule deconstruct_gbz:
    input:
        graph=GBZ_GRAPH,
    output:
        DECONSTRUCTED_VCF,
    params:
        selector_flag=deconstruct_selector_flag,
        selector_value=deconstruct_selector_value,
        options=lambda wildcards: " ".join(
            option
            for enabled, option in (
                (bool(config.get("deconstruct", {}).get("all_snarls", True)), "--all-snarls"),
                (bool(config.get("deconstruct", {}).get("contig_only_ref", True)), "--contig-only-ref"),
                (bool(config.get("deconstruct", {}).get("keep_conflicted", False)), "--keep-conflicted"),
            )
            if enabled
        ),
        outdir=lambda wildcards, output: str(Path(output[0]).parent),
        logdir=f"{LOG_DIR}/deconstruct",
    threads:
        cfg_threads("deconstruct", 8)
    resources:
        mem_mb=cfg_mem("deconstruct", 32768),
    log:
        f"{LOG_DIR}/deconstruct/{{name}}.deconstruct.log",
    conda:
        "../../envs/vg.yaml"
    shell:
        r"""
        mkdir -p {params.outdir:q} {params.logdir:q}
        vg deconstruct \
            {params.selector_flag} {params.selector_value:q} \
            {params.options} \
            --threads {threads} \
            {input.graph:q} > {output:q} 2> {log:q}
        test -s {output:q}
        """
