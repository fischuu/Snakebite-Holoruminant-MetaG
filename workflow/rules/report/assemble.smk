rule report__assemble:
    """Render the assemble module PDF report: assembly/binning/dereplication summary, runtime"""
    input:
        rules.assemble.input,
    output:
        pdf=PIPELINE_REPORT / "assemble.pdf",
    log:
        PIPELINE_REPORT / "assemble.log",
    benchmark:
        PIPELINE_REPORT / "assemble_benchmark.tsv",
    container:
        docker["r_report"]
    params:
        script=ASSEMBLE_R,
        pipeline_folder=config["pipeline_folder"],
        features=config["features-file"],
        sample_file=config["sample-file"],
        project_folder=WD,
    threads: esc("cpus", "report__assemble")
    resources:
        runtime=esc("runtime", "report__assemble"),
        mem_mb=esc("mem_mb", "report__assemble"),
        cpus_per_task=esc("cpus", "report__assemble"),
        slurm_partition=esc("partition", "report__assemble"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'report__assemble')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("report__assemble"))
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
