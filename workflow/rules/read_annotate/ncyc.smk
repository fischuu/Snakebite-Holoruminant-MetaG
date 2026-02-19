rule read_annotate__ncyc__prepare_input:
    """Create sample sheet for NCycDB Perl wrapper (runs all samples at once)"""
    input:
        forwards=[
            PRE_BOWTIE2 / "decontaminated_reads" / f"{sample_id}.{library_id}_1.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
        reverses=[
            PRE_BOWTIE2 / "decontaminated_reads" / f"{sample_id}.{library_id}_2.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
    output:
        NCYC / "ncyc_samples.tsv",
    log:
        NCYC / "log" / "ncyc_samples.log",
    benchmark:
        NCYC / "benchmark" / "ncyc_samples.tsv",
    container:
        docker["mag_annotate"],
    threads: esc("cpus", "read_annotate__ncyc__prepare_input")
    resources:
        runtime=esc("runtime", "read_annotate__ncyc__prepare_input"),
        mem_mb=esc("mem_mb", "read_annotate__ncyc__prepare_input"),
        cpus_per_task=esc("cpus", "read_annotate__ncyc__prepare_input"),
        slurm_partition=esc("partition", "read_annotate__ncyc__prepare_input"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__ncyc__prepare_input')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__ncyc__prepare_input"))
    params:
        folder=config["pipeline_folder"],
        reads=PRE_BOWTIE2 / "decontaminated_reads",
        outdir=NCYC / "results",
    shell:
        """
        echo "=== Running read_annotate__ncyc__prepare_input ===" > {log} 2>&1

        {params.folder}/workflow/scripts/prepare_ncyc_inputs.sh {params.reads} {output} fq.gz >> {log} 2>&1
        
        echo "=== Finished read_annotate__ncyc__prepare_input ===" >> {log} 2>&1
        """

rule read_annotate__ncyc__run:
    """Run NCycDB Perl wrapper on all samples"""
    input:
        NCYC / "ncyc_samples.tsv",
    output:
        NCYC / "ncyc_results.tsv",
    log:
        NCYC / "log" / "ncyc_run.log",
    benchmark:
        NCYC / "benchmark" / "ncyc_run.tsv",
    container:
        docker["mag_annotate"]
    threads: esc("cpus", "read_annotate__ncyc__run")
    resources:
        runtime=esc("runtime", "read_annotate__ncyc__run"),
        mem_mb=esc("mem_mb", "read_annotate__ncyc__run"),
        cpus_per_task=esc("cpus", "read_annotate__ncyc__run"),
        slurm_partition=esc("partition", "read_annotate__ncyc__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__ncyc__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__ncyc__run"))
    params:
        folder=config["pipeline_folder"],
        outdir=NCYC,
        reads_dir=PRE_BOWTIE2 / "decontaminated_reads" ,
        faa=features["databases"]["ncyc"],
    shell:
        """
        echo "=== Running read_annotate__ncyc__run ===" > {log} 2>&1

        # Extract the database folder (we assume that all files are in the same ncyc folder)
        db_faa={params.faa}
        db_folder=$(dirname "$db_faa")

        perl {params.folder}/workflow/scripts/NCycProfiler.PL \
                            -d {params.reads_dir} \
                            -db_faa {params.faa} \
                            -db_folder $db_folder \
                            -m diamond -f fq.gz -s nucl \
                            -si {input}  \
                            -of {params.outdir} \
                            -o {output} >> {log} 2>&1
        
        echo "=== Finished read_annotate__ncyc__run ===" >> {log} 2>&1
        """

rule read_annotate__ncyc:
    input:
        rules.read_annotate__ncyc__run.output
