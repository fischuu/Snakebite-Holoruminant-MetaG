rule reference__hosts__recompress:
    """Recompress one host genome with bgzip, which samtools faidx needs"""
    input:
        lambda wildcards: features["hosts"][wildcards.genome],
    output:
        HOST_FASTA,
    log:
        HOST_GENOMES / "{genome}.log",
    benchmark:
        HOST_GENOMES / "benchmark/{genome}.tsv"
    container:
        docker["reference"]
    threads: esc("cpus", "reference__hosts__recompress")
    resources:
        runtime=esc("runtime", "reference__hosts__recompress"),
        mem_mb=esc("mem_mb", "reference__hosts__recompress"),
        cpus_per_task=esc("cpus", "reference__hosts__recompress"),
        slurm_partition=esc("partition", "reference__hosts__recompress"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'reference__hosts__recompress')['nvme']}",
        attempt=esc("attempt", "reference__hosts__recompress"),
    shell:
        """
        exec > {log} 2>&1
        echo "[$(date)] recompressing {wildcards.genome} with bgzip"
        debug "threads={threads} input={input} output={output}"
        zcat {input} | bgzip -@ {threads} > {output}
        echo "[$(date)] done"
        """


rule reference__hosts:
    """Aggregate the recompressed genome for every configured host"""
    input:
        expand(HOST_FASTA, genome=HOST_NAMES),
