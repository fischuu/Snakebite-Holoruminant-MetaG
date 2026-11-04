rule qc__fragile__run:
    """Fails on the small resource set, to show how a rule climbs the escalation"""
    output:
        "results/qc/fragile.txt",
    log:
        "results/qc/fragile.log",
    threads: esc("cpus", "qc__fragile__run")
    resources:
        runtime=esc("runtime", "qc__fragile__run"),
        mem_mb=esc("mem_mb", "qc__fragile__run"),
        cpus_per_task=esc("cpus", "qc__fragile__run"),
        slurm_partition=esc("partition", "qc__fragile__run"),
        attempt=esc("attempt", "qc__fragile__run"),
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        echo "attempt {resources.attempt}: {resources.mem_mb} MB, {threads} CPUs, partition {resources.slurm_partition}"
        if [ {resources.mem_mb} -lt 500 ]; then
            echo "Pretending to run out of memory"
            exit 1
        fi
        echo "finished with {resources.mem_mb} MB" > {output}
        mv "$try_log" {log}
        """
