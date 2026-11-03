rule report__contig_annotate:
    """Render the contig_annotate module PDF report: gene prediction/annotation summary, runtime"""
    input:
        rules.contig_annotate.input,
    output:
        pdf=PIPELINE_REPORT / "contig_annotate.pdf",
    log:
        PIPELINE_REPORT / "contig_annotate.log",
    benchmark:
        PIPELINE_REPORT / "contig_annotate_benchmark.tsv",
    container:
        docker["r_report"]
    params:
        script=CONTIG_ANNOTATE_R,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
    threads: esc("cpus", "report__contig_annotate")
    resources:
        runtime=esc("runtime", "report__contig_annotate"),
        mem_mb=esc("mem_mb", "report__contig_annotate"),
        cpus_per_task=esc("cpus", "report__contig_annotate"),
        slurm_partition=esc("partition", "report__contig_annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__contig_annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__contig_annotate"))
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
