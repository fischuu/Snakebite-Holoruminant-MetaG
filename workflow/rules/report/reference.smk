rule report__reference:
    """Report on the host genomes and the configured databases, data volume and resources"""
    input:
        rules.reference.input,
    output:
        pdf=PIPELINE_REPORT / "reference.pdf",
        folder=directory(PIPELINE_REPORT / "reference"),
    log:
        PIPELINE_REPORT / "reference.log",
    benchmark:
        PIPELINE_REPORT / "reference_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("reference"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__reference")
    resources:
        runtime=esc("runtime", "report__reference"),
        mem_mb=esc("mem_mb", "report__reference"),
        cpus_per_task=esc("cpus", "report__reference"),
        slurm_partition=esc("partition", "report__reference"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__reference')['nvme']}",
        attempt=esc("attempt", "report__reference"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=reference project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
