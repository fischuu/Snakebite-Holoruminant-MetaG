rule mag_annotate__quast:
    """Assess assembly quality of the dereplicated genome set with QUAST"""
    input:
        DREP / "dereplicated_genomes.fa.gz",
    output:
        directory(QUAST),
    log:
        QUAST / "quast.log",
    benchmark:
        QUAST / "benchmark.tsv",
    container:
        docker["mag_annotate"]
    threads: esc("cpus", "mag_annotate__quast")
    resources:
        runtime=esc("runtime", "mag_annotate__quast"),
        mem_mb=esc("mem_mb", "mag_annotate__quast"),
        cpus_per_task=esc("cpus", "mag_annotate__quast"),
        slurm_partition=esc("partition", "mag_annotate__quast"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__quast')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__quast"))
    shell:
        """
        exec > {log} 2>&1
        quast --output-dir {output} --threads {threads} {input}
        """
