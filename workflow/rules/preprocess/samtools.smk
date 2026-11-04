rule preprocess__samtools__stats_cram:
    """Mapping statistics of one library on one host genome with samtools stats"""
    input:
        cram=HOST_CRAM,
        crai=HOST_CRAI,
        genome=HOST_FASTA,
        fai=HOST_FAI,
    output:
        HOST_MAPPING / "{genome}" / f"{LIBRARY}.stats.txt",
    log:
        HOST_MAPPING / "{genome}" / f"{LIBRARY}.stats.log",
    benchmark:
        HOST_MAPPING / "benchmark/{genome}" / f"{LIBRARY}.stats.tsv"
    container:
        docker["preprocess"]
    threads: esc("cpus", "preprocess__samtools__stats_cram")
    resources:
        runtime=esc("runtime", "preprocess__samtools__stats_cram"),
        mem_mb=esc("mem_mb", "preprocess__samtools__stats_cram"),
        cpus_per_task=esc("cpus", "preprocess__samtools__stats_cram"),
        slurm_partition=esc("partition", "preprocess__samtools__stats_cram"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__samtools__stats_cram')['nvme']}",
        attempt=esc("attempt", "preprocess__samtools__stats_cram"),
    shell:
        """
        exec 2> {log}
        debug "genome={wildcards.genome} library={wildcards.sample_id}.{wildcards.library_id} cram={input.cram}"
        samtools stats --reference {input.genome} {input.cram} > {output}
        """


rule preprocess__samtools:
    """Collect samtools stats/flagstats for every host-mapping CRAM"""
    input:
        [
            HOST_MAPPING / genome / f"{sample_id}.{library_id}.{ext}"
            for genome in HOST_NAMES
            for sample_id, library_id in SAMPLE_LIBRARY
            for ext in ("stats.txt", "flagstats.txt")
        ],
