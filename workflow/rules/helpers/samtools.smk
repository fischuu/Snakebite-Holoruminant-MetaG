rule helpers__samtools__index_bam:
    """Index a bam file"""
    input:
        "{prefix}.bam"
    output:
        "{prefix}.bam.bai"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__index_bam")
    resources:
        runtime=esc("runtime", "helpers__samtools__index_bam"),
        mem_mb=esc("mem_mb", "helpers__samtools__index_bam"),
        cpus_per_task=esc("cpus", "helpers__samtools__index_bam"),
        slurm_partition=esc("partition", "helpers__samtools__index_bam"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'helpers__samtools__index_bam')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("helpers__samtools__index_bam"))
    log:
        "{prefix}.bam.bai.log"
    benchmark:
        "benchmark/{prefix}.bam.bai.tsv"
    shell:"""
        echo "=== Running helpers__samtools__index_bam ===" > {log} 1>&2
        samtools index {input} 2>> {log} 1>&2
        echo "=== Finished helpers__samtools__index_bam ===" > {log} 1>&2
    """
  

rule helpers__samtools__index_cram:
    """Index a cram file"""
    input:
        "{prefix}.cram"
    output:
        "{prefix}.cram.crai"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__index_cram")
    resources:
        runtime=esc("runtime", "helpers__samtools__index_cram"),
        mem_mb=esc("mem_mb", "helpers__samtools__index_cram"),
        cpus_per_task=esc("cpus", "helpers__samtools__index_cram"),
        slurm_partition=esc("partition", "helpers__samtools__index_cram"),
    retries: len(get_escalation_order("helpers__samtools__index_cram"))
    log:
        "{prefix}.cram.crai.log"
    benchmark:
        "benchmark/{prefix}.cram.crai.tsv"
    shell:
        "samtools index {input} 2> {log} 1>&2"


rule helpers__samtools__faidx_fa:
    """Index a fasta file"""
    input:
        "{prefix}.fa"
    output:
        "{prefix}.fa.fai"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__faidx_fa")
    resources:
        runtime=esc("runtime", "helpers__samtools__faidx_fa"),
        mem_mb=esc("mem_mb", "helpers__samtools__faidx_fa"),
        cpus_per_task=esc("cpus", "helpers__samtools__faidx_fa"),
        slurm_partition=esc("partition", "helpers__samtools__faidx_fa"),
    retries: len(get_escalation_order("helpers__samtools__faidx_fa"))
    log:
        "{prefix}.fa.fai.log"
    benchmark:
        "benchmark/{prefix}.fa.fai.tsv"
    shell:
        "samtools faidx {input} 2> {log} 1>&2"

rule helpers__samtools__faidx_fagz:
    """Index a gzipped fasta file"""
    input:
        "{prefix}.fa.gz"
    output:
        fai="{prefix}.fa.gz.fai",
        gzi="{prefix}.fa.gz.gzi"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__faidx_fagz")
    resources:
        runtime=esc("runtime", "helpers__samtools__faidx_fagz"),
        mem_mb=esc("mem_mb", "helpers__samtools__faidx_fagz"),
        cpus_per_task=esc("cpus", "helpers__samtools__faidx_fagz"),
        slurm_partition=esc("partition", "helpers__samtools__faidx_fagz"),
    retries: len(get_escalation_order("helpers__samtools__faidx_fagz"))
    log:
        "{prefix}.fa.gz.log"
    benchmark:
        "benchmark/{prefix}.fa.gz.tsv"
    shell:
        "samtools faidx {input} 2> {log} 1>&2"


rule helpers__samtools__idxstats_cram:
    """Compute idxstats for a cram"""
    input:
        cram="{prefix}.cram",
        crai="{prefix}.cram.crai"
    output:
        tsv="{prefix}.idxstats.tsv"
    log:
        "{prefix}.idxstats.log"
    benchmark:
        "benchmark/{prefix}.idxstats.tsv"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__idxstats_cram")
    resources:
        runtime=esc("runtime", "helpers__samtools__idxstats_cram"),
        mem_mb=esc("mem_mb", "helpers__samtools__idxstats_cram"),
        cpus_per_task=esc("cpus", "helpers__samtools__idxstats_cram"),
        slurm_partition=esc("partition", "helpers__samtools__idxstats_cram"),
    retries: len(get_escalation_order("helpers__samtools__idxstats_cram"))
    shell:
        "samtools idxstats {input.cram} > {output.tsv} 2> {log}"


rule helpers__samtools__flagstats_cram:
    """Compute flagstats for a cram"""
    input:
        cram="{prefix}.cram",
        crai="{prefix}.cram.crai"
    output:
        txt="{prefix}.flagstats.txt"
    log:
        "{prefix}.flagstats.log"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__samtools__flagstats_cram")
    resources:
        runtime=esc("runtime", "helpers__samtools__flagstats_cram"),
        mem_mb=esc("mem_mb", "helpers__samtools__flagstats_cram"),
        cpus_per_task=esc("cpus", "helpers__samtools__flagstats_cram"),
        slurm_partition=esc("partition", "helpers__samtools__flagstats_cram"),
    retries: len(get_escalation_order("helpers__samtools__flagstats_cram"))
    shell:
        "samtools flagstats {input.cram} > {output.txt} 2> {log}"
