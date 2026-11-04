rule report__reads:
    """Report on the raw reads: samples, read numbers, quality, data volume and resources"""
    input:
        rules.reads.input,
    output:
        pdf=PIPELINE_REPORT / "reads.pdf",
        folder=directory(PIPELINE_REPORT / "reads"),
    log:
        PIPELINE_REPORT / "reads.log",
    benchmark:
        PIPELINE_REPORT / "reads_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("reads"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__reads")
    resources:
        runtime=esc("runtime", "report__reads"),
        mem_mb=esc("mem_mb", "report__reads"),
        cpus_per_task=esc("cpus", "report__reads"),
        slurm_partition=esc("partition", "report__reads"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__reads')['nvme']}",
        attempt=esc("attempt", "report__reads"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=reads project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
