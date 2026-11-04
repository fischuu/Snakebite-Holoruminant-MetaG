rule report__eukaryote:
    """Report on eukaryotic contigs and bins, data volume and resources"""
    input:
        rules.eukaryote.input,
    output:
        pdf=PIPELINE_REPORT / "eukaryote.pdf",
        folder=directory(PIPELINE_REPORT / "eukaryote"),
    log:
        PIPELINE_REPORT / "eukaryote.log",
    benchmark:
        PIPELINE_REPORT / "eukaryote_benchmark.tsv"
    container:
        REPORT_IMAGE
    params:
        script=REPORT_SCRIPT,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
        rule_table=lambda wc: report_rule_table("eukaryote"),
        version=version,
        snakemake_version=SNAKEMAKE_VERSION,
    threads: esc("cpus", "report__eukaryote")
    resources:
        runtime=esc("runtime", "report__eukaryote"),
        mem_mb=esc("mem_mb", "report__eukaryote"),
        cpus_per_task=esc("cpus", "report__eukaryote"),
        slurm_partition=esc("partition", "report__eukaryote"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__eukaryote')['nvme']}",
        attempt=esc("attempt", "report__eukaryote"),
    shell:
        """
        exec > {log} 2>&1
        Rscript {params.script} module=eukaryote project={params.project_folder} \
            pipeline={params.pipeline_folder} features={params.features} samples={params.sample_file} \
            output={output.pdf} version={params.version} snakemake={params.snakemake_version} \
            rules={params.rule_table:q}
        """
