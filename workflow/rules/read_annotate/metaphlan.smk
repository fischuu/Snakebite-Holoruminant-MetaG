rule read_annotate__metaphlan__run:
    """Run metaphlan over one sample
    """
    input:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        data=features["databases"]["metaphlan4"],
    output:
        bt2_out=METAPHLAN / "bowtie2_out" / "{sample_id}.{library_id}.bz2",
        mp_out=METAPHLAN / "profiled" / "{sample_id}.{library_id}.txt",
    log:
        METAPHLAN / "log" / "{sample_id}.{library_id}.log",
    benchmark:
        METAPHLAN / "benchmark" / "{sample_id}.{library_id}.tsv",
    container:
        docker["preprocess"]
    threads: esc("cpus", "read_annotate__metaphlan__run")
    resources:
        runtime=esc("runtime", "read_annotate__metaphlan__run"),
        mem_mb=esc("mem_mb", "read_annotate__metaphlan__run"),
        cpus_per_task=esc("cpus", "read_annotate__metaphlan__run"),
        slurm_partition=esc("partition", "read_annotate__metaphlan__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__metaphlan__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__metaphlan__run"))
    params:
        tmp = config["tmp_storage"]
    shell:
        """
        TMPDIR={params.tmp}

        metaphlan {input.forward_},{input.reverse_} \
                  --bowtie2out {output.bt2_out} \
                  --nproc {threads} \
                  --input_type fastq \
                  -o {output.mp_out} \
                  --bowtie2db {input.data} \
        2>> {log} 1>&2
        """


rule read_annotate__metaphlan__condense:
    """Aggregate all the metaphlan results into a single table"""
    input:
        profiled_data=[
            METAPHLAN / "profiled" / f"{sample_id}.{library_id}.txt"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]
    output:
        METAPHLAN / "metaphlan_profiled.tsv",
    log:
        METAPHLAN / "metaphlan.log",
    benchmark:
        METAPHLAN / "benchmark/metaphlan.tsv",
    container:
        docker["preprocess"]
    params:
        input_dir=METAPHLAN,
    threads: esc("cpus", "read_annotate__metaphlan__condense")
    resources:
        runtime=esc("runtime", "read_annotate__metaphlan__condense"),
        mem_mb=esc("mem_mb", "read_annotate__metaphlan__condense"),
        cpus_per_task=esc("cpus", "read_annotate__metaphlan__condense"),
        slurm_partition=esc("partition", "read_annotate__metaphlan__condense"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__metaphlan__condense')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__metaphlan__condense"))
    shell:
        """
        merge_metaphlan_tables.py {input.profiled_data} > {output} 2> {log}
        """

rule read_annotate__metaphlan:
    input:
        rules.read_annotate__metaphlan__condense.output
