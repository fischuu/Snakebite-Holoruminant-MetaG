rule report__mag_annotate:
    """Render the mag_annotate module PDF report: CheckM2/GTDB-Tk/QUAST/DRAM summaries, runtime"""
    input:
        rules.mag_annotate.input,
    output:
        pdf=PIPELINE_REPORT / "mag_annotate.pdf",
    log:
        PIPELINE_REPORT / "mag_annotate.log",
    benchmark:
        PIPELINE_REPORT / "mag_annotate_benchmark.tsv",
    container:
        docker["r_report"]
    params:
        script=MAG_ANNOTATE_R,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
    threads: esc("cpus", "report__mag_annotate")
    resources:
        runtime=esc("runtime", "report__mag_annotate"),
        mem_mb=esc("mem_mb", "report__mag_annotate"),
        cpus_per_task=esc("cpus", "report__mag_annotate"),
        slurm_partition=esc("partition", "report__mag_annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__mag_annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__mag_annotate"))
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
