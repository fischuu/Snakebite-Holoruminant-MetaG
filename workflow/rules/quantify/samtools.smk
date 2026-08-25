rule quantify__samtools__stats_cram:
    """Run `samtools stats` on one MAG-mapping CRAM"""
    input:
        cram=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram",
        crai=QUANT_BOWTIE2 / "{sample_id}.{library_id}.cram.crai",
        reference=DREP / "dereplicated_genomes.fa.gz",
        fai=DREP / "dereplicated_genomes.fa.gz.fai",
    output:
        txt=QUANT_BOWTIE2 / "{sample_id}.{library_id}.stats.txt",
    log:
        QUANT_BOWTIE2 / "{sample_id}.{library_id}.stats.log",
    benchmark:
        QUANT_BOWTIE2 / "benchmark/{sample_id}.{library_id}.stats.tsv",
    container:
        docker["quantify"]
    threads: esc("cpus", "quantify__samtools__stats_cram")
    resources:
        runtime=esc("runtime", "quantify__samtools__stats_cram"),
        mem_mb=esc("mem_mb", "quantify__samtools__stats_cram"),
        cpus_per_task=esc("cpus", "quantify__samtools__stats_cram"),
        slurm_partition=esc("partition", "quantify__samtools__stats_cram"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'quantify__samtools__stats_cram')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("quantify__samtools__stats_cram"))
    shell:
        "samtools stats --reference {input.reference} {input.cram} > {output.txt} 2> {log}"


rule quantify__samtools:
    """Collect samtools stats/flagstats for every MAG-mapping CRAM"""
    input:
        [
            QUANT_BOWTIE2 / f"{sample_id}.{library_id}.{ext}"
            for sample_id, library_id in SAMPLE_LIBRARY
            for ext in ("stats.txt", "flagstats.txt")
        ],
