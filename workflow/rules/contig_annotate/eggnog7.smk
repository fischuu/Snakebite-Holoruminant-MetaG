rule contig_annotate__eggnog7__run:
    """
    Run the eggnog annotator for version 7
    """
    input:
        fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa",
    output:
        CONTIG_EGGNOG7 / "{assembly_id}/{assembly_id}.eggnog.tsv.gz",
    params:
        sample=lambda wildcards: f"{wildcards.assembly_id}",
        out=CONTIG_EGGNOG7,
        db=features["databases"]["eggnog7"],
        folder=config["pipeline_folder"],
    log:
        CONTIG_EGGNOG7 / "logs/{assembly_id}_eggnog.log"
    benchmark:
        CONTIG_EGGNOG7 / "benchmark/{assembly_id}.tsv"
    threads: esc("cpus", "contig_annotate__eggnog7__run")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog7__run"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog7__run"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog7__run"),
        slurm_partition=esc("partition", "contig_annotate__eggnog7__run"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog7__run')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__eggnog7__run"))
    container:
        docker["eggnog"]
    shell:"""
      {params.folder}/workflow/scripts/eggnog7_annotator.sh \
      -d {params.db}_proteins.dmnd \
      -q {input.fa} \
      -m {params.db}_master_search_table.tsv.gz \
      -s {params.sample} \
      -o {params.out}/{params.sample} \
      -p {threads} 2> {log} 1>&2
    """    
    
rule contig_annotate__eggnog7:
    """Run eggnog on all assemblies"""
    input:
        expand(CONTIG_EGGNOG7 / "{assembly_id}/{assembly_id}.eggnog.tsv.gz", assembly_id=ASSEMBLIES),
