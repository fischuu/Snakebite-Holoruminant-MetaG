rule report__assemble:
    """Report on assembly, binning and the genome catalogue, data volume and resources"""
    input:
        module_results(rules.assemble, "assemble"),
    output:
        pdf=PIPELINE_REPORT / "assemble.pdf",
        folder=directory(PIPELINE_REPORT / "assemble"),
    log:
        PIPELINE_REPORT / "assemble.log",
    benchmark:
        PIPELINE_REPORT / "assemble_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("assemble"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__assemble")
    resources:
        runtime=esc("runtime", "report__assemble"),
        mem_mb=esc("mem_mb", "report__assemble"),
        cpus_per_task=esc("cpus", "report__assemble"),
        slurm_partition=esc("partition", "report__assemble"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__assemble')['nvme']}",
        attempt=esc("attempt", "report__assemble"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=assemble project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
