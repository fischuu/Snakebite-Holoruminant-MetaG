rule read_annotate__sylph_profile:
    """Run Sylph profiler"""
    input:
        forwards=CLEAN_FORWARD,
        reverses=CLEAN_REVERSE,
        db=features["databases"]["sylph"],
    output:
        PRE_SYLPH / "{sample_id}.{library_id}.profiling.tsv",
    log:
        PRE_SYLPH / "{sample_id}.{library_id}.profiling_report.log",
    benchmark:
        PRE_SYLPH / "benchmark/{sample_id}.{library_id}.tsv",
    container:
        docker["sylph"]
    threads: esc("cpus", "read_annotate__sylph_profile")
    resources:
        runtime=esc("runtime", "read_annotate__sylph_profile"),
        mem_mb=esc("mem_mb", "read_annotate__sylph_profile"),
        cpus_per_task=esc("cpus", "read_annotate__sylph_profile"),
        slurm_partition=esc("partition", "read_annotate__sylph_profile"),
        #gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__sylph_profile')['nvme']}",
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__sylph_profile')['nvme']}",
        attempt=esc("attempt", "read_annotate__sylph_profile"),
    retries: len(get_escalation_order("read_annotate__sylph_profile"))
    shell:
        """
        echo "Starting Sylph rule attempt {resources.attempt}" > {log}
        debug "threads={threads} forwards={input.forwards} reverses={input.reverses} db={input.db}" 2>> {log}

        # Below this line is a dev part for testing the resubmission and escalation 
        # if [ {resources.attempt} -le 2 ]; then
        #    echo "Failing intentionally on attempt {resources.attempt}" >> {log}
        #    ls --nonexistentflag
        #fi
        
        sylph profile {input.db} -1 {input.forwards} -2 {input.reverses} -t {threads} > {output} 2>> {log}
        """


rule read_annotate__sylph:
    """Run Sylph"""
    input:
        [
            PRE_SYLPH / f"{sample_id}.{library_id}.profiling.tsv"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]
