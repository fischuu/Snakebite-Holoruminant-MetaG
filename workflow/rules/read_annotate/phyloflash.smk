rule read_annotate__phyloflash__run:
    """Run PhyloFlash over one sample
    """
    input:
        forward_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_1.fq.gz",
        reverse_=PRE_BOWTIE2 / "decontaminated_reads" / "{sample_id}.{library_id}_2.fq.gz",
        phyloflash_dbs=PHYLOFLASH_DBS,
    output:
        phyloflash_out=PHYLOFLASH / "{sample_id}_{library_id}.phyloFlash.html",
        phyloflash_log=PHYLOFLASH / "{sample_id}_{library_id}.phyloFlash.log",
    log:
        PHYLOFLASH / "log" / "{sample_id}.{library_id}.log",
    benchmark:
        PHYLOFLASH / "benchmark" / "{sample_id}.{library_id}.tsv",
    container:
        docker["phyloflash"]
    threads: esc("cpus", "read_annotate__phyloflash__run")
    resources:
        runtime=esc("runtime", "read_annotate__phyloflash__run"),
        mem_mb=esc("mem_mb", "read_annotate__phyloflash__run"),
        cpus_per_task=esc("cpus", "read_annotate__phyloflash__run"),
        slurm_partition=esc("partition", "read_annotate__phyloflash__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__phyloflash__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__phyloflash__run"))
    params:
        lib="{sample_id}_{library_id}",
        outdir=PHYLOFLASH
    shell:
        """
        phyloFlash.pl -dbhome {input.phyloflash_dbs} \
                      -lib {params.lib} -CPUs {threads} \
                      -read1 {input.forward_} \
                      -read2 {input.reverse_} \
                      -almosteverything 2>> {log} 1>&2

        mkdir -p {params.outdir}
        mv {params.lib}.* {params.outdir}
        """


rule read_annotate__phyloflash__condense:
    """Aggregate all the PhyloFlash results into a single table"""
    input:
        phyloflash_logs=[
            PHYLOFLASH / f"{sample_id}_{library_id}.phyloFlash.log"
            for sample_id, library_id in SAMPLE_LIBRARY
        ]
    output:
        PHYLOFLASH / "phyloflash_all.log",
    log:
        PHYLOFLASH / "phyloflash.log",
    benchmark:
        PHYLOFLASH / "benchmark/phyloflash.tsv",
    container:
        docker["phyloflash"]
    params:
        input_dir=PHYLOFLASH,
    threads: esc("cpus", "read_annotate__phyloflash__condense")
    resources:
        runtime=esc("runtime", "read_annotate__phyloflash__condense"),
        mem_mb=esc("mem_mb", "read_annotate__phyloflash__condense"),
        cpus_per_task=esc("cpus", "read_annotate__phyloflash__condense"),
        slurm_partition=esc("partition", "read_annotate__phyloflash__condense"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__phyloflash__condense')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__phyloflash__condense"))
    shell:
        """
        cat {input.phyloflash_logs} > {output} 2> {log}
        """

rule read_annotate__phyloflash:
    input:
        rules.read_annotate__phyloflash__condense.output
