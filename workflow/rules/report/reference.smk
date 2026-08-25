rule report__reference:
    """Render the reference module PDF report: configured hosts, recompression runtime"""
    input:
        rules.reference.input,
    output:
        pdf=PIPELINE_REPORT / "reference.pdf",
    log:
        PIPELINE_REPORT / "reference.log",
    benchmark:
        PIPELINE_REPORT / "reference_benchmark.tsv",
    container:
        docker["r_report"]
    params:
        script=REFERENCE_R,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
    threads: esc("cpus", "report__reference")
    resources:
        runtime=esc("runtime", "report__reference"),
        mem_mb=esc("mem_mb", "report__reference"),
        cpus_per_task=esc("cpus", "report__reference"),
        slurm_partition=esc("partition", "report__reference"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__reference')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__reference"))
    shell:
        """
        exec > {log} 2>&1
        R -e "project_folder <- '{params.project_folder}'; \
              pipeline_folder <- '{params.pipeline_folder}'; \
              features_file <- '{params.features}'; \
              sample_file <- '{params.sample_file}'; \
              rmarkdown::render('{params.script}', output_format='pdf_document', \
                                 output_file=file.path('{params.project_folder}', '{output.pdf}'))"
        """
