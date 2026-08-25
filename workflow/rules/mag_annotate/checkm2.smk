rule mag_annotate__checkm2__predict:
    """Assess genome completeness/contamination of the dereplicated MAGs with CheckM2"""
    input:
        mags=DREP / "dereplicated_genomes",
        db=features["databases"]["checkm2"],
    output:
        CHECKM / "quality_report.tsv",
    log:
        CHECKM / "quality_report.log",
    benchmark:
        CHECKM / "benchmark.tsv",
    container:
        docker["checkm2"]
    params:
        out_dir=CHECKM / "predict",
    threads: esc("cpus", "mag_annotate__checkm2__predict")
    resources:
        runtime=esc("runtime", "mag_annotate__checkm2__predict"),
        mem_mb=esc("mem_mb", "mag_annotate__checkm2__predict"),
        cpus_per_task=esc("cpus", "mag_annotate__checkm2__predict"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__checkm2__predict')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__checkm2__predict"))
    shell:
        """
        exec > {log} 2>&1
        rm --recursive --force --verbose {params.out_dir}

        checkm2 predict \
            --threads {threads} \
            --input {input.mags} \
            --extension .fa.gz \
            --output-directory {params.out_dir} \
            --database_path {input.db} \
            --remove_intermediates

        mv {params.out_dir}/quality_report.tsv {output}
        rm --recursive --force --verbose {params.out_dir}
        """


rule mag_annotate__checkm2:
    """Run CheckM2"""
    input:
        rules.mag_annotate__checkm2__predict.output,
