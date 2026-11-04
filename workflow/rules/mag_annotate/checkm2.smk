rule mag_annotate__checkm2__predict:
    """Assess genome completeness/contamination of the dereplicated MAGs with CheckM2"""
    input:
        genomes=MAG_GENOMES,
        reference_data=features["databases"]["checkm2"],
    output:
        CHECKM2 / "quality_report.tsv",
    log:
        CHECKM2 / "quality_report.log",
    benchmark:
        CHECKM2 / "benchmark.tsv",
    container:
        docker["checkm2"]
    threads: esc("cpus", "mag_annotate__checkm2__predict")
    resources:
        runtime=esc("runtime", "mag_annotate__checkm2__predict"),
        mem_mb=esc("mem_mb", "mag_annotate__checkm2__predict"),
        cpus_per_task=esc("cpus", "mag_annotate__checkm2__predict"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__checkm2__predict')['nvme']}",
        attempt=esc("attempt", "mag_annotate__checkm2__predict"),
    shell:
        """
        exec > {log} 2>&1
        workdir={CHECKM2}/predict
        debug "threads={threads} genomes={input.genomes} reference_data={input.reference_data} workdir=$workdir"
        rm -rf "$workdir"

        checkm2 predict -i {input.genomes} -x .fa.gz -o "$workdir" -t {threads} \
            --database_path {input.reference_data} --remove_intermediates

        mv "$workdir/quality_report.tsv" {output}
        rm -rf "$workdir"
        """


rule mag_annotate__checkm2:
    """Assess all MAGs with CheckM2"""
    input:
        rules.mag_annotate__checkm2__predict.output,
