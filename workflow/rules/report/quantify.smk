rule report__quantify:
    """Report on the abundance of genomes and contigs, data volume and resources"""
    input:
        module_results(rules.quantify, "quantify"),
    output:
        pdf=PIPELINE_REPORT / "quantify.pdf",
        folder=directory(PIPELINE_REPORT / "quantify"),
    log:
        PIPELINE_REPORT / "quantify.log",
    benchmark:
        PIPELINE_REPORT / "quantify_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("quantify"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__quantify")
    resources:
        runtime=esc("runtime", "report__quantify"),
        mem_mb=esc("mem_mb", "report__quantify"),
        cpus_per_task=esc("cpus", "report__quantify"),
        slurm_partition=esc("partition", "report__quantify"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__quantify')['nvme']}",
        attempt=esc("attempt", "report__quantify"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=quantify project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
