rule quantify__samtools__stats_cram:
    """Mapping statistics of one library on the MAG catalogue with samtools stats"""
    input:
        alignment=MAG_CRAM,
        index=MAG_CRAI,
        catalogue=MAG_CATALOGUE,
        fai=MAG_CATALOGUE_FAI,
    output:
        MAG_MAPPING / f"{LIBRARY}.stats.txt",
    log:
        MAG_MAPPING / f"{LIBRARY}.stats.log",
    benchmark:
        MAG_MAPPING / f"benchmark/{LIBRARY}.stats.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__samtools__stats_cram")
    resources:
        runtime=esc("runtime", "quantify__samtools__stats_cram"),
        mem_mb=esc("mem_mb", "quantify__samtools__stats_cram"),
        cpus_per_task=esc("cpus", "quantify__samtools__stats_cram"),
        slurm_partition=esc("partition", "quantify__samtools__stats_cram"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__samtools__stats_cram')['nvme']}",
        attempt=esc("attempt", "quantify__samtools__stats_cram"),
    shell:
        """
        exec 2> {log}
        debug "library={wildcards.sample_id}.{wildcards.library_id} output={output}"
        samtools stats --reference {input.catalogue} {input.alignment} > {output}
        """


rule quantify__samtools:
    """Collect samtools stats/flagstats for every MAG-mapping CRAM"""
    input:
        [
            MAG_MAPPING / f"{sample_id}.{library_id}.{ext}"
            for sample_id, library_id in SAMPLE_LIBRARY
            for ext in ("stats.txt", "flagstats.txt")
        ],
