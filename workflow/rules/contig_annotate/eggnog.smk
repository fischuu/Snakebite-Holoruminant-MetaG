from glob import glob
from os.path import join

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
        partition=esc("partition", "contig_annotate__eggnog_find_homology"),
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


         emapper.py -m diamond --data_dir $DATA_DIR --override --no_annot --no_file_comments --cpu {threads} -i {input.files} --output_dir {params.folder} -o {params.out}  2>> {log} 1>&2;
    """
    
rule contig_annotate__eggnog_orthology_chunk:
    """
    Annotate eggnog hits table per chunk (EGGNOG) using /dev/shm for speed,
    with usage counter to ensure DB is only deleted once all jobs are finished.
    """
    input:
        seed=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs"
    output:
        annotation=CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations",
        done = CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.done"
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.log"
    threads: esc("cpus", "contig_annotate__eggnog_orthology_chunk")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog_orthology_chunk"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog_orthology_chunk"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog_orthology_chunk"),
        partition=esc("partition", "contig_annotate__eggnog_orthology_chunk"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog_orthology_chunk')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__eggnog_orthology_chunk"))    
    container:
        docker["mag_annotate"]
    params:
        fa = features["databases"]["eggnog"],
        out = lambda wc: f"prodigal.chunk.{wc.i}",
        outdir = lambda wc: CONTIG_EGGNOG / f"{wc.assembly_id}/Chunks",
        run_in_shm=config["eggnog_shm"],
        copy_dbs=config["copy_dbs"],
        shm=config["shm_storage"],
        nvme=config["nvme_storage"],
    shell: """
     
      # check if dbs should be copied, otherwise use the original location
        if [ {params.copy_dbs} = "True" ]; then
        
          # check first which destination to use (shm or nvme)
            if [ "{params.run_in_shm}" = "True" ]; then
              echo "Config allowed /dev/shm use for this rule" 2>> {log} 1>&2
              DATA_DIR="{params.shm}/eggnog_data"
            else
              echo "Config disallowed /dev/shm use for this rule, using nvme space instead" 2>> {log} 1>&2
              DATA_DIR="{params.nvme}/eggnog_data"
            fi          
            
          # Initiate the copy and chunk running
            LOCK_FILE="$DATA_DIR/.lock"
            DONE_FILE="$DATA_DIR/.done"
            COUNTER_FILE="$DATA_DIR/.counter"
    
            mkdir -p $DATA_DIR
    
            # === Increment counter safely ===
            (
                flock -x 200
                COUNT=0
                if [ -f "$COUNTER_FILE" ]; then
                    COUNT=$(cat "$COUNTER_FILE")
                fi
                COUNT=$((COUNT + 1))
                echo $COUNT > "$COUNTER_FILE"
                echo "Incremented counter: $COUNT jobs using DB" >> {log}
            ) 200>"$COUNTER_FILE.lock"
    
            # === Copy DB if not already done ===
            if [ ! -f "$DONE_FILE" ]; then
                if mkdir "$LOCK_FILE" 2>/dev/null; then
                    echo "This job has the lock, copying DB..." >> {log}
                    cp -r {params.fa}/* $DATA_DIR/ >> {log} 2>&1
                    touch "$DONE_FILE"
                    rmdir "$LOCK_FILE"
                else
                    echo "Another job is copying the DB, waiting..." >> {log}
                    while [ ! -f "$DONE_FILE" ]; do
                        sleep 30
                    done
                fi
            fi
      # If db copy is not requested, use the original location
        else 
            DATA_DIR={params.fa}
        fi

        # === Run emapper ===
        mkdir -p {params.outdir}
        emapper.py --data_dir $DATA_DIR \
                   --annotate_hits_table {input.seed} \
                   --no_file_comments \
                   -o {params.out} \
                   --output_dir {params.outdir} \
                   --override \
                   --cpu {threads} >> {log} 2>&1

        # === Decrement counter and cleanup if last job ===
        (
            flock -x 200
            COUNT=$(cat "$COUNTER_FILE")
            COUNT=$((COUNT - 1))
            if [ $COUNT -le 0 ]; then
                echo 0 > "$COUNTER_FILE"
                echo "No more jobs using DB, cleaning $DATA_DIR" >> {log}
                rm -rf "$DATA_DIR"
                rm -f "$DONE_FILE"
            else
                echo $COUNT > "$COUNTER_FILE"
                echo "Remaining jobs using DB: $COUNT" >> {log}
            fi
        ) 200>"$COUNTER_FILE.lock"

        touch {output.done}
    """

    
rule contig_annotate__eggnog_merge_annotations:
    input:
        contig_annotate_aggregate_annotations_eggnog_search,
    output:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations"
    log:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations.log"
    shell:"""
       cat {input} > {output} 2> {log}
    """


rule contig_annotate__eggnog:
    """Run eggnog on all assemblies"""
    input:
        [CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations" for assembly_id in ASSEMBLIES],
