rule report__mag_annotate:
    """Report on genome quality, taxonomy and annotation, data volume and resources"""
    input:
        module_results(rules.mag_annotate, "mag_annotate"),
    output:
        pdf=PIPELINE_REPORT / "mag_annotate.pdf",
        folder=directory(PIPELINE_REPORT / "mag_annotate"),
    log:
        PIPELINE_REPORT / "mag_annotate.log",
    benchmark:
        PIPELINE_REPORT / "mag_annotate_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("mag_annotate"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__mag_annotate")
    resources:
        runtime=esc("runtime", "report__mag_annotate"),
        mem_mb=esc("mem_mb", "report__mag_annotate"),
        cpus_per_task=esc("cpus", "report__mag_annotate"),
        slurm_partition=esc("partition", "report__mag_annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__mag_annotate')['nvme']}",
        attempt=esc("attempt", "report__mag_annotate"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=mag_annotate project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
