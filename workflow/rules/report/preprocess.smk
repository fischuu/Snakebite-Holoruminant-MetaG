rule report__preprocess:
    """Report on trimming and host removal: what happened to the reads, data volume and resources"""
    input:
        rules.preprocess.input,
    output:
        pdf=PIPELINE_REPORT / "preprocess.pdf",
        folder=directory(PIPELINE_REPORT / "preprocess"),
    log:
        PIPELINE_REPORT / "preprocess.log",
    benchmark:
        PIPELINE_REPORT / "preprocess_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("preprocess"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__preprocess")
    resources:
        runtime=esc("runtime", "report__preprocess"),
        mem_mb=esc("mem_mb", "report__preprocess"),
        cpus_per_task=esc("cpus", "report__preprocess"),
        slurm_partition=esc("partition", "report__preprocess"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__preprocess')['nvme']}",
        attempt=esc("attempt", "report__preprocess"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=preprocess project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
