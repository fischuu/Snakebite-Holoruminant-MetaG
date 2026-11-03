rule helpers__fastqc:
    """Generic FastQC rule: report for any {prefix}.fq.gz, reused across modules"""
    input:
        "{prefix}.fq.gz"
    output:
        html="{prefix}_fastqc.html",
        zip="{prefix}_fastqc.zip"
    container:
        docker["helpers"]
    threads: esc("cpus", "helpers__fastqc")
    resources:
        runtime=esc("runtime", "helpers__fastqc"),
        mem_mb=esc("mem_mb", "helpers__fastqc"),
        cpus_per_task=esc("cpus", "helpers__fastqc"),
        slurm_partition=esc("partition", "helpers__fastqc"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'helpers__fastqc')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("helpers__fastqc"))
    log:
        "{prefix}_fastqc.log"
    benchmark:
        "{prefix}_fastqc_benchmark.tsv"
    shell:
        "fastqc {input} > {log} 2>&1"
