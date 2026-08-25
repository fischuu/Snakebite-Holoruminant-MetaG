rule read_annotate__singlem__pipe:
    """Profile marker-gene taxonomy for one sample with SingleM

    SingleM's own docs recommend raw reads, but this pipeline feeds it the
    decontaminated, quality-trimmed reads instead, consistent with every
    other read-based annotation tool here.
    """
    input:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        data=features["databases"]["singlem"], 
    output:
        archive_otu_table=SINGLEM / "pipe" / "{sample_id}.{library_id}.archive.json",
        otu_table=SINGLEM / "pipe" / "{sample_id}.{library_id}.otu_table.tsv",
        condense=SINGLEM / "pipe" / "{sample_id}.{library_id}.condense.tsv",
    log:
        SINGLEM / "pipe" / "{sample_id}.{library_id}.log",
    benchmark:
        SINGLEM / "benchmark/pipe" / "{sample_id}.{library_id}.tsv",
    container:
        docker["preprocess"]
    threads: esc("cpus", "read_annotate__singlem__pipe")
    resources:
        runtime=esc("runtime", "read_annotate__singlem__pipe"),
        mem_mb=esc("mem_mb", "read_annotate__singlem__pipe"),
        cpus_per_task=esc("cpus", "read_annotate__singlem__pipe"),
        slurm_partition=esc("partition", "read_annotate__singlem__pipe"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__singlem__pipe')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__singlem__pipe"))
    params:
        tmp = config["tmp_storage"]
    shell:
        """
        export TMPDIR={params.tmp}
        exec > {log} 2>&1

        echo "TMPDIR disk space (${{TMPDIR:-/tmp}}):"
        df -h "${{TMPDIR:-/tmp}}"

        singlem pipe \
            --forward {input.forward_} \
            --reverse {input.reverse_} \
            --otu-table {output.otu_table} \
            --archive-otu-table {output.archive_otu_table} \
            --taxonomic-profile {output.condense} \
            --metapackage {input.data} \
            --threads {threads} \
            --assignment-threads {threads}
        """


rule read_annotate__singlem__condense:
    """Aggregate all the singlem results into a single table"""
    input:
        archive_otu_tables=[
            SINGLEM / "pipe" / f"{sample_id}.{library_id}.archive.json"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
        database=features["databases"]["singlem"],
    output:
        condense=SINGLEM / "singlem.tsv",
    log:
        SINGLEM / "singlem.log",
    benchmark:
        SINGLEM / "benchmark/singlem.tsv",
    container:
        docker["preprocess"]
    params:
        input_dir=SINGLEM,
    threads: esc("cpus", "read_annotate__singlem__condense")
    resources:
        runtime=esc("runtime", "read_annotate__singlem__condense"),
        mem_mb=esc("mem_mb", "read_annotate__singlem__condense"),
        cpus_per_task=esc("cpus", "read_annotate__singlem__condense"),
        slurm_partition=esc("partition", "read_annotate__singlem__condense"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__singlem__condense')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__singlem__condense"))
    shell:
        """
        exec > {log} 2>&1
        singlem condense \
            --input-archive-otu-tables {input.archive_otu_tables} \
            --taxonomic-profile {output.condense} \
            --metapackage {input.database}
        """


rule read_annotate__singlem__microbial_fraction:
    """Run singlem microbial_fraction over one sample"""
    input:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        data=features["databases"]["singlem"],
        condense=SINGLEM / "pipe" / "{sample_id}.{library_id}.condense.tsv",
    output:
        microbial_fraction=SINGLEM
        / "microbial_fraction"
        / "{sample_id}.{library_id}.tsv",
    log:
        SINGLEM / "microbial_fraction" / "{sample_id}.{library_id}.log",
    benchmark:
        SINGLEM / "benchmark/microbial_fraction" / "{sample_id}.{library_id}.tsv"
    container:
        docker["preprocess"]
    threads: esc("cpus", "read_annotate__singlem__microbial_fraction")
    resources:
        runtime=esc("runtime", "read_annotate__singlem__microbial_fraction"),
        mem_mb=esc("mem_mb", "read_annotate__singlem__microbial_fraction"),
        cpus_per_task=esc("cpus", "read_annotate__singlem__microbial_fraction"),
        slurm_partition=esc("partition", "read_annotate__singlem__microbial_fraction"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__singlem__microbial_fraction')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__singlem__microbial_fraction"))
    shell:
        """
        exec > {log} 2>&1
        singlem microbial_fraction \
            --forward {input.forward_} \
            --reverse {input.reverse_} \
            --input-profile {input.condense} \
            --output-tsv {output.microbial_fraction} \
            --metapackage {input.data}
        """


rule read_annotate__singlem__aggregate_microbial_fraction:
    """Aggregate all the microbial_fraction files into one tsv"""
    input:
        tsvs=[
            SINGLEM / "microbial_fraction" / f"{sample_id}.{library_id}.tsv"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
    output:
        tsv=SINGLEM / "microbial_fraction.tsv",
    log:
        SINGLEM / "microbial_fraction.log",
    benchmark:
        SINGLEM / "benchmark/microbial_fraction.tsv"
    container:
        docker["preprocess"]
    threads: esc("cpus", "read_annotate__singlem__aggregate_microbial_fraction")
    resources:
        runtime=esc("runtime", "read_annotate__singlem__aggregate_microbial_fraction"),
        mem_mb=esc("mem_mb", "read_annotate__singlem__aggregate_microbial_fraction"),
        cpus_per_task=esc("cpus", "read_annotate__singlem__aggregate_microbial_fraction"),
        slurm_partition=esc("partition", "read_annotate__singlem__aggregate_microbial_fraction"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__singlem__aggregate_microbial_fraction')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__singlem__aggregate_microbial_fraction"))
    shell:
        """
        exec 2> {log}
        csvstack --tabs {input.tsvs} | csvformat --out-tabs > {output.tsv}
        """

rule read_annotate__singlem:
    """Aggregate the SingleM taxonomic profile and microbial-fraction results"""
    input:
        rules.read_annotate__singlem__condense.output,
        rules.read_annotate__singlem__aggregate_microbial_fraction.output,
