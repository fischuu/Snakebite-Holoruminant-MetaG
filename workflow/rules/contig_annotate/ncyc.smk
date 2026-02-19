rule contig_annotate__ncyc__prepare_input:
    """Create sample sheet for NCycDB Perl wrapper (runs all samples at once)"""
    input:
        [CONTIG_PRODIGAL / f"{assembly_id}/{assembly_id}.prodigal.fa" for assembly_id in ASSEMBLIES],
    output:
        CONTIG_NCYC / "ncyc_samples.tsv",
    log:
        CONTIG_NCYC / "log" / "ncyc_samples.log",
    benchmark:
        CONTIG_NCYC / "benchmark" / "ncyc_samples.tsv",
    container:
        docker["mag_annotate"],
    threads: esc("cpus", "contig_annotate__ncyc__prepare_input")
    resources:
        runtime=esc("runtime", "contig_annotate__ncyc__prepare_input"),
        mem_mb=esc("mem_mb", "contig_annotate__ncyc__prepare_input"),
        cpus_per_task=esc("cpus", "contig_annotate__ncyc__prepare_input"),
        slurm_partition=esc("partition", "contig_annotate__ncyc__prepare_input"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__ncyc__prepare_input')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__ncyc__prepare_input"))
    params:
        folder=config["pipeline_folder"],
        input_dir=CONTIG_NCYC / "input",
        outdir=NCYC / "results",
    shell:
        """
        echo "=== Running contig_annotate__ncyc__prepare_input ===" > {log} 2>&1

        mkdir -p {params.input_dir}
        
        # Link prodigal fasta files into CONTIG_NCYC/input
        for fasta in {input}; do
            ln -sf $(realpath $fasta) {params.input_dir}/$(basename $fasta)
        done

        {params.folder}/workflow/scripts/prepare_ncyc_inputs.sh {params.input_dir} {output} fa >> {log} 2>&1
        
        echo "=== Finished contig_annotate__ncyc__prepare_input ===" >> {log} 2>&1
        """

rule contig_annotate__ncyc__run:
    """Run NCycDB Perl wrapper on all samples from prodigal"""
    input:
        CONTIG_NCYC / "ncyc_samples.tsv",
    output:
        CONTIG_NCYC / "ncyc_results.tsv",
    log:
        CONTIG_NCYC / "log" / "ncyc_run.log",
    benchmark:
        CONTIG_NCYC / "benchmark" / "ncyc_run.tsv",
    container:
        docker["mag_annotate"]
    threads: esc("cpus", "contig_annotate__ncyc__run")
    resources:
        runtime=esc("runtime", "contig_annotate__ncyc__run"),
        mem_mb=esc("mem_mb", "contig_annotate__ncyc__run"),
        cpus_per_task=esc("cpus", "contig_annotate__ncyc__run"),
        slurm_partition=esc("partition", "contig_annotate__ncyc__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__ncyc__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__ncyc__run"))
    params:
        folder=config["pipeline_folder"],
        outdir=CONTIG_NCYC,
        input_dir=CONTIG_NCYC / "input",
        faa=features["databases"]["ncyc"],
    shell:
        """
        echo "=== Running contig_annotate__ncyc__run ===" > {log} 2>&1

        # Extract the database folder (we assume that all files are in the same ncyc folder)
        db_faa={params.faa}
        db_folder=$(dirname "$db_faa")

        perl {params.folder}/workflow/scripts/NCycProfiler.PL \
                            -d {params.input_dir} \
                            -db_faa {params.faa} \
                            -db_folder $db_folder \
                            -m diamond -f fa -s prot \
                            -si {input}  \
                            -of {params.outdir} \
                            -o {output} >> {log} 2>&1
        
        echo "=== Finished contig_annotate__ncyc__run ===" >> {log} 2>&1
        """

rule contig_annotate__ncyc:
    input:
        rules.contig_annotate__ncyc__run.output
