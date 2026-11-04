rule report__read_annotate:
    """Report on the read-based taxonomy and function, data volume and resources"""
    input:
        rules.read_annotate.input,
    output:
        pdf=PIPELINE_REPORT / "read_annotate.pdf",
        folder=directory(PIPELINE_REPORT / "read_annotate"),
    log:
        PIPELINE_REPORT / "read_annotate.log",
    benchmark:
        PIPELINE_REPORT / "read_annotate_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("read_annotate"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__read_annotate")
    resources:
        runtime=esc("runtime", "report__read_annotate"),
        mem_mb=esc("mem_mb", "report__read_annotate"),
        cpus_per_task=esc("cpus", "report__read_annotate"),
        slurm_partition=esc("partition", "report__read_annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__read_annotate')['nvme']}",
        attempt=esc("attempt", "report__read_annotate"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=read_annotate project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
