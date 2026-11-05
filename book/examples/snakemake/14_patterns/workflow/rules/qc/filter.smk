rule qc__filter__run:
    """Keep the reads of at least the configured length"""
    input:
        lambda wildcards: samples.loc[samples["sample_id"] == wildcards.sample, "forward_filename"].iloc[0],
    output:
        "results/qc/{sample}.fastq.gz",
    log:
        "results/qc/{sample}.log",
    params:
        min_length=params["qc"]["min_length"],
    threads: esc("cpus", "qc__filter__run")
    resources:
        runtime=esc("runtime", "qc__filter__run"),
        mem_mb=esc("mem_mb", "qc__filter__run"),
        cpus_per_task=esc("cpus", "qc__filter__run"),
        slurm_partition=esc("partition", "qc__filter__run"),
        attempt=esc("attempt", "qc__filter__run"),
    shell:
        """
        try_log={log}.try{resources.attempt}
        exec > "$try_log" 2>&1
        debug "sample={wildcards.sample} threads={threads} min_length={params.min_length}"

        zcat {input} | paste - - - - | awk -F '\\t' -v min={params.min_length} 'length($2) >= min' \
            | tr '\\t' '\\n' | gzip > {output}

        mv "$try_log" {log}
        """
