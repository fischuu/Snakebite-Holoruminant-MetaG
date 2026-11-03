rule report__quantify:
    """Render the quantify module PDF report: CoverM genome/contig abundance summary, runtime"""
    input:
        rules.quantify.input,
    output:
        pdf=PIPELINE_REPORT / "quantify.pdf",
    log:
        PIPELINE_REPORT / "quantify.log",
    benchmark:
        PIPELINE_REPORT / "quantify_benchmark.tsv",
    container:
        docker["r_report"]
    params:
        script=QUANTIFY_R,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
    threads: esc("cpus", "report__quantify")
    resources:
        runtime=esc("runtime", "report__quantify"),
        mem_mb=esc("mem_mb", "report__quantify"),
        cpus_per_task=esc("cpus", "report__quantify"),
        slurm_partition=esc("partition", "report__quantify"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__quantify')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__quantify"))
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
