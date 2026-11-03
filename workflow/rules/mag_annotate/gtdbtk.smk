rule mag_annotate__gtdbtk__classify:
    """Place the MAGs in the GTDB taxonomy with the classify workflow of GTDB-Tk"""
    input:
        genomes=MAG_GENOMES,
        reference_data=features["databases"]["gtdbtk"],
    output:
        merged_summary=GTDBTK / "gtdbtk.summary.tsv",
        archives=expand(GTDBTK / "{part}.tar.gz", part=("align", "classify", "identify")),
    log:
        GTDBTK / "gtdbtk_classify.log",
    benchmark:
        GTDBTK / "benchmark.tsv",
    container:
        docker["gtdbtk"]
    threads: esc("cpus", "mag_annotate__gtdbtk__classify")
    resources:
        runtime=esc("runtime", "mag_annotate__gtdbtk__classify"),
        mem_mb=esc("mem_mb", "mag_annotate__gtdbtk__classify"),
        cpus_per_task=esc("cpus", "mag_annotate__gtdbtk__classify"),
        slurm_partition=esc("partition", "mag_annotate__gtdbtk__classify"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__gtdbtk__classify')['nvme']}",
        attempt=esc("attempt", "mag_annotate__gtdbtk__classify"),
    retries: len(get_escalation_order("mag_annotate__gtdbtk__classify"))
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        ar53={GTDBTK}/gtdbtk.ar53.summary.tsv
        bac120={GTDBTK}/gtdbtk.bac120.summary.tsv
        debug "attempt={resources.attempt} threads={threads} reference_data={input.reference_data}"

        # Results of a failed attempt must not get in the way
        rm -rf {GTDBTK}/{{align,classify,identify,gtdbtk_classify.log,gtdbtk.json,gtdbtk.summary.tsv,gtdbtk.warnings.log}} \
            "$ar53" "$bac120"

        GTDBTK_DATA_PATH={input.reference_data} gtdbtk classify_wf \
            --genome_dir {input.genomes} -x fa.gz --out_dir {GTDBTK} --cpus {threads} --skip_ani_screen

        # Not every set of MAGs contains archaea, and only then is there an ar53 table
        if [[ -f "$ar53" ]]; then
            csvstack -t "$bac120" "$ar53" | csvformat -T > {output.merged_summary}
        else
            cp "$bac120" {output.merged_summary}
        fi

        for part in align classify identify; do
            tar -C {GTDBTK} -cv -I "pigz -p {threads}" -f {GTDBTK}/$part.tar.gz $part
        done

        mv "$try_log" {log}
        """


rule mag_annotate__gtdbtk:
    """Classify the MAGs with GTDB-Tk"""
    input:
        rules.mag_annotate__gtdbtk__classify.output,
