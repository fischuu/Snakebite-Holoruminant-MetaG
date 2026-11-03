rule read_annotate__krona__visualize:
    """
    Create Krona plots for Kraken2 output.
    """
    input:
        KRAKEN2 / "{kraken_db}" / "{sample_id}.{library_id}.report",
    output:
        KRONA / "{kraken_db}" / "{sample_id}.{library_id}.html",
    log:
        KRONA / "{kraken_db}_{sample_id}.{library_id}.log",
    benchmark:
        KRONA / "benchmark/{kraken_db}_{sample_id}.{library_id}bsk.tsv",
    threads: esc("cpus", "read_annotate__krona__visualize")
    resources:
        runtime=esc("runtime", "read_annotate__krona__visualize"),
        mem_mb=esc("mem_mb", "read_annotate__krona__visualize"),
        cpus_per_task=esc("cpus", "read_annotate__krona__visualize"),
        slurm_partition=esc("partition", "read_annotate__krona__visualize"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__krona__visualize')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__krona__visualize"))
    container:
        docker["krona"]
    params:
        krona_db = features["databases"]["krona"],
    shell:
        """
        debug "input={input} output={output} krona_db={params.krona_db}" 2> {log}
        ktImportTaxonomy -q 2 -t 3 {input} -o {output} --tax {params.krona_db} 2>> {log} 1>&2
        """

rule read_annotate__krona:
    """Run krona for the kraken output"""
    input:
        [
            KRONA / kraken_db / f"{sample_id}.{library_id}.html"
            for sample_id, library_id in SAMPLE_LIBRARY
            for kraken_db in features["databases"]["kraken2"]
        ],
