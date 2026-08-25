rule reference__hosts__recompress:
    """Ensure a reference host genome is bgzip-compressed"""
    input:
        fa_gz=lambda wildcards: features["hosts"][wildcards.genome],
    output:
        HOSTS / "{genome}.fa.gz",
    log:
        HOSTS / "{genome}.log",
    benchmark:
        HOSTS / "benchmark/{genome}.tsv",
    container:
        docker["reference"]
    threads: esc("cpus", "reference__hosts__recompress")
    resources:
        runtime=esc("runtime", "reference__hosts__recompress"),
        mem_mb=esc("mem_mb", "reference__hosts__recompress"),
        cpus_per_task=esc("cpus", "reference__hosts__recompress"),
        slurm_partition=esc("partition", "reference__hosts__recompress"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'reference__hosts__recompress')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("reference__hosts__recompress"))
    shell:
        """
        exec > {log} 2>&1
        echo "[$(date)] recompressing {wildcards.genome} with bgzip"
        zcat {input.fa_gz} | bgzip --threads {threads} > {output}
        echo "[$(date)] done"
        """


rule reference__hosts:
    """Aggregate the recompressed genome for every configured host"""
    input:
        [HOSTS / f"{genome}.fa.gz" for genome in HOST_NAMES],
