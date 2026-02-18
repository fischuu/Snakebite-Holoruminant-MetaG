rule contig_annotate__eggnog_find_homology:
    """
    Find homolog genes in data (EGGNOG).
    """
    input:
        folder = CONTIG_PRODIGAL / "{assembly_id}/Chunks/",
        files = CONTIG_PRODIGAL / "{assembly_id}/Chunks/prodigal.chunk.{i}"
    output:
        file=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.log"
    params:
        folder = lambda wildcards: CONTIG_EGGNOG / f"{wildcards.assembly_id}/Chunks/",
        tmp=config["nvme_storage"],
        out="prodigal.chunk.{i}",
        fa=features["databases"]["eggnog"]
    threads: esc("cpus", "contig_annotate__eggnog_find_homology")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog_find_homology"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog_find_homology"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog_find_homology"),
        slurm_partition=esc("partition", "contig_annotate__eggnog_find_homology"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog_find_homology')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__eggnog_find_homology"))
    container:
        docker["mag_annotate"]
    shell:""" 
        DATA_DIR="{params.tmp}"

        if [ -z "$DATA_DIR" ]; then
            DATA_DIR="{params.fa}"
        else
            cp {params.fa}/eggnog* {params.tmp} &> {log};
        fi;


         emapper.py -m diamond --data_dir $DATA_DIR --no_annot --no_file_comments --cpu {threads} -i {input.files} --output_dir {params.folder} -o {params.out}  2>> {log} 1>&2;
    """
    
                  
rule contig_annotate__aggregate_assemblies_eggnog:
    input:
        contig_annotate_aggregate_assembly_eggnog_search,
    output:
        CONTIG_EGGNOG / "{assembly_id}/prodigal.emapper.seed_orthologs"
    log:
        CONTIG_EGGNOG / "{assembly_id}/prodigal.emapper.seed_orthologs.log"
    container:
        docker["mag_annotate"]
    shell:"""
       cat {input} > {output} 2> {log}
    """
    
rule contig_annotate__eggnog_orthology:
    """
    Find orthology and annotate (EGGNOG).
    """
    input:
        CONTIG_EGGNOG / "{assembly_id}/prodigal.emapper.seed_orthologs",
    output:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations",
    log:
        CONTIG_EGGNOG / "{assembly_id}/prodigal.emapper.annotations.log",
    params:
        tmp=config["nvme_storage"],
        fa=features["databases"]["eggnog"],
        out = lambda wildcards: CONTIG_EGGNOG / f"{wildcards.assembly_id}/eggnog_output",
    threads: esc("cpus", "contig_annotate__eggnog_orthology")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog_orthology"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog_orthology"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog_orthology"),
        slurm_partition=esc("partition", "contig_annotate__eggnog_orthology"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog_orthology')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__eggnog_orthology"))
    container:
        docker["mag_annotate"]
    shell:"""
    # Actually, not sure if that makes any sense, I think the files should not be concatenated here, but treated still here concatenated and then rather be merged afterwards
    # For now it is alright, as we annotated approx 650 per seconds (=run takes around a day), but if you ever rerun this step again, change it that it will be processed on the chunks
    # and then merge the chunks!

        DATA_DIR="{params.tmp}"

        if [ -z "$DATA_DIR" ]; then
            DATA_DIR="{params.fa}"
        else
            cp {params.fa}/eggnog* {params.tmp} &> {log};
        fi;
        
       emapper.py --data_dir $DATA_DIR --annotate_hits_table {input} --no_file_comments -o {params.out} --cpu {threads} &> {log}
    """
   
    
rule contig_annotate__eggnog:
    """Run eggnog on all assemblies"""
    input:
        [CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations" for assembly_id in ASSEMBLIES],
