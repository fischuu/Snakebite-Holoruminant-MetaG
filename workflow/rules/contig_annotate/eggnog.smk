from glob import glob
from os.path import join


rule contig_annotate__eggnog_find_homology:
    """
    Find homolog genes in data (EGGNOG).
    """
    input:
        folder=CONTIG_PRODIGAL / "{assembly_id}/Chunks/",
        files=CONTIG_PRODIGAL / "{assembly_id}/Chunks/prodigal.chunk.{i}",
    output:
        file=CONTIG_EGGNOG
        / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs",
    log:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/prodigal.chunk.{i}.log",
    benchmark:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/benchmark_homology.{i}.tsv"
    params:
        folder=lambda wildcards: CONTIG_EGGNOG / f"{wildcards.assembly_id}/Chunks/",
        tmp=config["nvme_storage"],
        out="prodigal.chunk.{i}",
        fa=features["databases"]["eggnog"],
    threads: esc("cpus", "contig_annotate__eggnog_find_homology")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog_find_homology"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog_find_homology"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog_find_homology"),
        slurm_partition=esc("partition", "contig_annotate__eggnog_find_homology"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog_find_homology')['nvme']}",
        attempt=esc("attempt", "contig_annotate__eggnog_find_homology"),
    container:
        docker["mag_annotate"]
    shell:
        """ 
        DATA_DIR="{params.tmp}"

        # If no nvme_storage tmp dir is configured, or the database doesn't fit into it, run emapper
        # straight against the shared eggnog DB location instead of staging a local copy.
        if [ -n "$DATA_DIR" ]; then
            db_size=$(du -cbL {params.fa}/eggnog* | tail -n 1 | cut -f1)
            tmp_avail=$(df --output=avail -B1 "$DATA_DIR" | tail -n 1)
            if [ "$db_size" -lt "$tmp_avail" ]; then
                # A folder of this job's own, removed again however the job ends (before, the
                # copy was never removed, and in the container $TMPDIR is on /scratch)
                DATA_DIR=$(mktemp -d "$DATA_DIR/eggnog_db.XXXXXX")
                trap 'rm -rf "$DATA_DIR"' EXIT
                trap 'exit 143' TERM INT
                cp {params.fa}/eggnog* "$DATA_DIR"/ &> {log}
            else
                DATA_DIR=""
            fi
        fi
        if [ -z "$DATA_DIR" ]; then
            DATA_DIR="{params.fa}"
        fi

        debug "assembly_id={wildcards.assembly_id} chunk={wildcards.i} threads={threads} DATA_DIR=$DATA_DIR" 2>> {log}

         emapper.py -m diamond --data_dir $DATA_DIR --override --no_annot --no_file_comments --cpu {threads} -i {input.files} --output_dir {params.folder} -o {params.out}  2>> {log} 1>&2;
    """


rule contig_annotate__eggnog_orthology_chunk:
    """
    Annotate eggnog hits table per chunk (EGGNOG) using /dev/shm for speed. The chunk jobs
    on a node share one copy of the DB, guarded by flock and a count of the jobs using it,
    and the last job removes it.
    """
    input:
        seed=CONTIG_EGGNOG
        / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.seed_orthologs",
    output:
        annotation=CONTIG_EGGNOG
        / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations",
        done=CONTIG_EGGNOG
        / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.done",
    log:
        CONTIG_EGGNOG
        / "{assembly_id}/Chunks/prodigal.chunk.{i}.emapper.annotations.log",
    benchmark:
        CONTIG_EGGNOG / "{assembly_id}/Chunks/benchmark_orthology.{i}.tsv"
    threads: esc("cpus", "contig_annotate__eggnog_orthology_chunk")
    resources:
        runtime=esc("runtime", "contig_annotate__eggnog_orthology_chunk"),
        mem_mb=esc("mem_mb", "contig_annotate__eggnog_orthology_chunk"),
        cpus_per_task=esc("cpus", "contig_annotate__eggnog_orthology_chunk"),
        slurm_partition=esc("partition", "contig_annotate__eggnog_orthology_chunk"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__eggnog_orthology_chunk')['nvme']}",
        attempt=esc("attempt", "contig_annotate__eggnog_orthology_chunk"),
    container:
        docker["mag_annotate"]
    params:
        fa=features["databases"]["eggnog"],
        out=lambda wc: f"prodigal.chunk.{wc.i}",
        outdir=lambda wc: CONTIG_EGGNOG / f"{wc.assembly_id}/Chunks",
        run_in_shm=config["eggnog_shm"],
        copy_dbs=config["copy_dbs"],
        shm=config["shm_storage"],
        nvme=config["nvme_storage"],
    shell:
        """
        exec >> {log} 2>&1
        debug "assembly_id={wildcards.assembly_id} chunk={wildcards.i} threads={threads} copy_dbs={params.copy_dbs} run_in_shm={params.run_in_shm}"

        DATA_DIR="{params.fa}"
        REGISTERED=false
        if [ "{params.copy_dbs}" = "True" ]; then
            if [ "{params.run_in_shm}" = "True" ]; then
                echo "Config allowed /dev/shm use for this rule"
                DATA_DIR="{params.shm}/eggnog_data"
            else
                echo "Config disallowed /dev/shm use for this rule, using nvme space instead"
                DATA_DIR="{params.nvme}/eggnog_data"
            fi

            # All chunk jobs on a node share one staged copy of the database. The lock and the
            # count of jobs using the copy are kept next to it, not inside it, so all jobs lock
            # the same file, also while the copy is removed or made again.
            LOCK_FILE="$DATA_DIR.lock"
            COUNTER_FILE="$DATA_DIR.users"

            # However the job ends (success, error, or TERM from SLURM), count this job out;
            # the last job using the copy removes it.
            release_db() {{
                rc=$?
                if [ "$REGISTERED" = true ]; then
                    (
                        flock -x 9
                        count=$(cat "$COUNTER_FILE" 2> /dev/null || echo 1)
                        count=$((count - 1))
                        if [ "$count" -le 0 ]; then
                            echo "No more jobs using the DB, removing $DATA_DIR"
                            rm -rf "$DATA_DIR" "$COUNTER_FILE"
                        else
                            echo "$count" > "$COUNTER_FILE"
                            echo "Remaining jobs using the DB: $count"
                        fi
                    ) 9> "$LOCK_FILE"
                fi
                exit "$rc"
            }}
            trap release_db EXIT
            trap 'exit 143' TERM INT

            # Copy (if needed) and count this job in, under one exclusive lock. Other jobs wait
            # on the lock rather than polling for a marker, and if the copying job dies, the
            # lock goes with it: the next job finds no .done marker and copies again, instead
            # of all jobs waiting forever.
            (
                flock -x 9
                if [ ! -f "$DATA_DIR/.done" ]; then
                    echo "Copying the eggnog DB to $DATA_DIR"
                    rm -rf "$DATA_DIR"
                    mkdir -p "$DATA_DIR"
                    cp -r {params.fa}/* "$DATA_DIR"/
                    touch "$DATA_DIR/.done"
                fi
                count=$(cat "$COUNTER_FILE" 2> /dev/null || echo 0)
                echo $((count + 1)) > "$COUNTER_FILE"
                echo "Jobs using the DB: $((count + 1))"
            ) 9> "$LOCK_FILE"
            REGISTERED=true
        fi

        # === Run emapper ===
        mkdir -p {params.outdir}
        debug "seed={input.seed} DATA_DIR=$DATA_DIR outdir={params.outdir} threads={threads}"
        emapper.py --data_dir "$DATA_DIR" \
                   --annotate_hits_table {input.seed} \
                   --no_file_comments \
                   -o {params.out} \
                   --output_dir {params.outdir} \
                   --override \
                   --cpu {threads}

        touch {output.done}
    """


rule contig_annotate__eggnog_merge_annotations:
    input:
        contig_annotate_aggregate_annotations_eggnog_search,
    output:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations",
    log:
        CONTIG_EGGNOG / "{assembly_id}/eggnog_output.emapper.annotations.log",
    benchmark:
        CONTIG_EGGNOG / "{assembly_id}/benchmark_merge_annotations.tsv"
    shell:
        """
       cat {input} > {output} 2> {log}
    """


rule contig_annotate__eggnog:
    """Run eggnog on all assemblies"""
    input:
        [
            CONTIG_EGGNOG / f"{assembly_id}/eggnog_output.emapper.annotations"
            for assembly_id in ASSEMBLIES
        ],
