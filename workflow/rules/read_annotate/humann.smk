rule read_annotate__humann__run:
    """Run HumanN3 over one sample"""
    input:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        prot_dbs=features["databases"]["humann_prot_dbs"],
        nt_dbs=features["databases"]["humann_nt_dbs"],
        mp_out=METAPHLAN / "profiled" / "{sample_id}.{library_id}.txt",
    output:
        humann_out=HUMANN / "{sample_id}.{library_id}_genefamilies.tsv",
        cat=temp(HUMANN / "{sample_id}.{library_id}_concatenated.fastq.gz"),
    log:
        HUMANN / "log" / "{sample_id}.{library_id}.log",
    benchmark:
        HUMANN / "benchmark" / "{sample_id}.{library_id}.tsv",
    container:
        docker["humann"],
    params:
        out_folder=HUMANN,
        out_name="{sample_id}.{library_id}",
        additional_options=params["read_annotate"]["humann"]["additional_options"],
    threads: esc("cpus", "read_annotate__humann__run"),
    resources:
        runtime=esc("runtime", "read_annotate__humann__run"),
        mem_mb=esc("mem_mb", "read_annotate__humann__run"),
        cpus_per_task=esc("cpus", "read_annotate__humann__run"),
        slurm_partition=esc("partition", "read_annotate__humann__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__humann__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__humann__run")),
    shell: """
         
        echo "In case this rule crashes for larger datasets, you need to ensure a proper size of TMPDIR!"
    
        echo "$(date) **Starting rule read_annotate__humann__run, attempt {resources.attempt}**" > {log}.{resources.attempt}

        cat {input.forward_} {input.reverse_} > {output.cat}
        
        humann --input {output.cat} --output {params.out_folder} \
               --threads {threads} \
               --protein-database {input.prot_dbs} \
               --nucleotide-database {input.nt_dbs} \
               --output-basename {params.out_name} \
               --taxonomic-profile {input.mp_out} \
               {params.additional_options} \
        2>> {log}.{resources.attempt} 1>&2

        echo "$(date) **Finished rule read_annotate__humann__run, attempt {resources.attempt}**" >> {log}.{resources.attempt}

        mv {log}.{resources.attempt} {log}
    """

rule read_annotate__humann__condense:
    """Aggregate all the HumanN results into a single table"""
    input:
        genefamily_data=[
            HUMANN / f"{sample_id}.{library_id}_genefamilies.tsv"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]
    output:
        HUMANN / "humann_genefamilies.tsv",
    log:
        HUMANN / "humann.log",
    benchmark:
        HUMANN / "benchmark/humann.tsv",
    container:
        docker["humann"]
    params:
        input_dir=HUMANN,
    threads: esc("cpus", "read_annotate__humann__condense"),
    resources:
        runtime=esc("runtime", "read_annotate__humann__condense"),
        mem_mb=esc("mem_mb", "read_annotate__humann__condense"),
        cpus_per_task=esc("cpus", "read_annotate__humann__condense"),
        slurm_partition=esc("partition", "read_annotate__humann__condense"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__humann__condense')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__humann__condense")),
    shell:
        """
        cat {input.genefamily_data} > {output}
        2> {log} 1>&2
        """

rule read_annotate__humann:
    input:
        rules.read_annotate__humann__condense.output
