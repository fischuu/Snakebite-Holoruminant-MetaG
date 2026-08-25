rule mag_annotate__gtdbtk__classify:
    """Taxonomically classify the dereplicated genomes with GTDB-Tk"""
    input:
        fasta_folder=DREP / "dereplicated_genomes",
        database=features["databases"]["gtdbtk"],
    output:
        summary=GTDBTK / "gtdbtk.summary.tsv",
        align=GTDBTK / "align.tar.gz",
        classify=GTDBTK / "classify.tar.gz",
        identify=GTDBTK / "identify.tar.gz",
    log:
        GTDBTK / "gtdbtk_classify.log",
    benchmark:
        GTDBTK / "benchmark.tsv",
    container:
        docker["gtdbtk"]
    params:
        out_dir=GTDBTK,
        ar53=GTDBTK / "gtdbtk.ar53.summary.tsv",
        bac120=GTDBTK / "gtdbtk.bac120.summary.tsv",
    threads: esc("cpus", "mag_annotate__gtdbtk__classify")
    resources:
        runtime=esc("runtime", "mag_annotate__gtdbtk__classify"),
        mem_mb=esc("mem_mb", "mag_annotate__gtdbtk__classify"),
        cpus_per_task=esc("cpus", "mag_annotate__gtdbtk__classify"),
        slurm_partition=esc("partition", "mag_annotate__gtdbtk__classify"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__gtdbtk__classify')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__gtdbtk__classify"))
    shell:
        """
        exec > {log}.{resources.attempt} 2>&1

        stale=(
            {params.out_dir}/align {params.out_dir}/classify {params.out_dir}/identify
            {params.out_dir}/gtdbtk_classify.log {params.out_dir}/gtdbtk.json
            {params.out_dir}/gtdbtk.summary.tsv {params.out_dir}/gtdbtk.warnings.log
            {params.ar53} {params.bac120}
        )
        rm --recursive --force -- "${{stale[@]}}"

        export GTDBTK_DATA_PATH="{input.database}"
        gtdbtk classify_wf \
            --genome_dir {input.fasta_folder} \
            --extension fa.gz \
            --out_dir {params.out_dir} \
            --cpus {threads} \
            --skip_ani_screen

        # Archaea (ar53) may or may not be present depending on the genome set;
        # merge it into the summary only when GTDB-Tk actually produced it.
        if [[ -f {params.ar53} ]]; then
            csvstack --tabs {params.bac120} {params.ar53} | csvformat --out-tabs > {output.summary}
        else
            cp {params.bac120} {output.summary}
        fi

        for section in align classify identify; do
            tar \
                --create \
                --directory {params.out_dir} \
                --file {params.out_dir}/${{section}}.tar.gz \
                --use-compress-program="pigz --processes {threads}" \
                --verbose \
                ${{section}}
        done

        mv {log}.{resources.attempt} {log}
        """


rule mag_annotate__gtdbtk:
    """Run the gtdbtk subworkflow"""
    input:
        rules.mag_annotate__gtdbtk__classify.output,
