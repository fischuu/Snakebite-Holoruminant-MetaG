rule preprocess__samtools__stats_cram:
    """Run `samtools stats` on one host-mapping CRAM"""
    input:
        cram=PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.cram",
        crai=PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.cram.crai",
        reference=HOSTS / "{genome}.fa.gz",
        fai=HOSTS / "{genome}.fa.gz.fai",
    output:
        txt=PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.stats.txt",
    log:
        PRE_BOWTIE2 / "{genome}" / "{sample_id}.{library_id}.stats.log",
    benchmark:
        PRE_BOWTIE2 / "benchmark/{genome}" / "{sample_id}.{library_id}.stats.tsv"
    container:
        docker["preprocess"]
    threads: esc("cpus", "preprocess__samtools__stats_cram")
    resources:
        runtime=esc("runtime", "preprocess__samtools__stats_cram"),
        mem_mb=esc("mem_mb", "preprocess__samtools__stats_cram"),
        cpus_per_task=esc("cpus", "preprocess__samtools__stats_cram"),
        slurm_partition=esc("partition", "preprocess__samtools__stats_cram"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'preprocess__samtools__stats_cram')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("preprocess__samtools__stats_cram"))
    shell:
        "samtools stats --reference {input.reference} {input.cram} > {output.txt} 2> {log}"


rule preprocess__samtools:
    """Collect samtools stats/flagstats for every host-mapping CRAM"""
    input:
        [
            PRE_BOWTIE2 / genome / f"{sample_id}.{library_id}.{ext}"
            for genome in HOST_NAMES
            for sample_id, library_id in SAMPLE_LIBRARY
            for ext in ("stats.txt", "flagstats.txt")
        ],
