rule read_annotate__nonpareil__run:
    """Estimate sequence coverage/diversity for one sample with Nonpareil

    Nonpareil only takes one read of the pair, and needs a real (decompressed)
    FASTQ file on disk -- it doesn't accept a process-substitution pipe. On
    low-coverage samples it can legitimately fail to converge, in which case
    it produces empty output files rather than erroring; the `touch()`
    wrappers below make sure Snakemake still sees the expected outputs.
    """
    input:
        forward_=CLEAN_FORWARD,
    output:
        touch(NONPAREIL / f"{LIBRARY}.npa"),
        touch(NONPAREIL / f"{LIBRARY}.npc"),
        touch(NONPAREIL / f"{LIBRARY}.npl"),
        touch(NONPAREIL / f"{LIBRARY}.npo"),
    log:
        NONPAREIL / f"{LIBRARY}.log",
    benchmark:
        NONPAREIL / f"benchmark/{LIBRARY}.tsv",
    container:
        docker["preprocess"]
    params:
        X=params["read_annotate"]["nonpareil"]["X"],
        tmp = config["tmp_storage"]
    threads: esc("cpus", "read_annotate__nonpareil__run")
    resources:
        runtime=esc("runtime", "read_annotate__nonpareil__run"),
        mem_mb=esc("mem_mb", "read_annotate__nonpareil__run"),
        cpus_per_task=esc("cpus", "read_annotate__nonpareil__run"),
        slurm_partition=esc("partition", "read_annotate__nonpareil__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__nonpareil__run')['nvme']}",
        attempt=esc("attempt", "read_annotate__nonpareil__run"),
    shell:
        """
        export TMPDIR={params.tmp}
        exec > {log} 2>&1
        prefix={NONPAREIL}/{wildcards.sample_id}.{wildcards.library_id}
        debug "threads={threads} X={params.X} prefix=$prefix"

        zcat {input.forward_} > "${{prefix}}_1.fq"
        nonpareil -s "${{prefix}}_1.fq" -T kmer -b "$prefix" -f fastq -t {threads} -X {params.X}
        rm -f "${{prefix}}_1.fq"
        """


rule read_annotate__nonpareil__aggregate:
    """Aggregate all the nonpareil results into a single table"""
    input:
        [f"{NONPAREIL}/{sample_id}.{library_id}.npo" for sample_id, library_id in SAMPLE_LIBRARY],
    output:
        NONPAREIL / "nonpareil.tsv",
    log:
        NONPAREIL / "nonpareil.log",
    benchmark:
        NONPAREIL / "benchmark/nonpareil.tsv",
    container:
        docker["preprocess"]
    threads: esc("cpus", "read_annotate__nonpareil__aggregate")
    resources:
        runtime=esc("runtime", "read_annotate__nonpareil__aggregate"),
        mem_mb=esc("mem_mb", "read_annotate__nonpareil__aggregate"),
        cpus_per_task=esc("cpus", "read_annotate__nonpareil__aggregate"),
        slurm_partition=esc("partition", "read_annotate__nonpareil__aggregate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__nonpareil__aggregate')['nvme']}",
        attempt=esc("attempt", "read_annotate__nonpareil__aggregate"),
    params:
        input_dir=NONPAREIL,
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        exec > {log} 2>&1
        debug "input_dir={params.input_dir} output={output}"
        Rscript --no-init-file {params.script_folder}/nonpareil_summary.R {params.input_dir} {output}
        """


rule read_annotate__nonpareil:
    input:
        rules.read_annotate__nonpareil__aggregate.output,
