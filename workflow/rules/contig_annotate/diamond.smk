rule contig_annotate__diamond__assign:
    """Run Diamond with SHM/NVME staging if possible."""
    input:
        fa=CONTIG_PRODIGAL / "{assembly_id}/{assembly_id}.prodigal.fa",
        database=lambda w: features["databases"]["diamond_contig_protein"][w.diamond_db],
    output:
        CONTIG_DIAMOND / "{diamond_db}" / "{assembly_id}.out",
    log:
        CONTIG_DIAMOND / "{diamond_db}_{assembly_id}.log",
    benchmark:
        CONTIG_DIAMOND / "benchmark/{diamond_db}_{assembly_id}.tsv",
    threads: esc("cpus", "contig_annotate__diamond__assign"),
    resources:
        runtime=esc("runtime", "contig_annotate__diamond__assign"),
        mem_mb=esc("mem_mb", "contig_annotate__diamond__assign"),
        cpus_per_task=esc("cpus", "contig_annotate__diamond__assign"),
        slurm_partition=esc("partition", "contig_annotate__diamond__assign"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__diamond__assign')['nvme']}",
        attempt=lambda wildcards, attempt: attempt,
    retries: len(get_escalation_order("contig_annotate__diamond__assign")) - 1,
    params:
        retries=len(get_escalation_order("contig_annotate__diamond__assign")) - 1,
        in_folder=FASTP,
        out_folder=lambda w: CONTIG_DIAMOND / w.diamond_db,
        run_in_shm=config["diamond_shm"],
        copy_dbs=config["copy_dbs"],
        diamond_shm=DIAMONDSHM,
        diamond_nvme=DIAMONDNVME,
        diamond_db_shm=lambda w: os.path.join(DIAMONDSHM, w.diamond_db),
        diamond_path=lambda w: os.path.basename(features["databases"]["diamond_contig_protein"][w.diamond_db]),
        diamond_db_nvme=lambda w: os.path.join(DIAMONDNVME, w.diamond_db),
    container:
        docker["mag_annotate"],
    shell:
        r"""
        set +u
        
        echo "Starting Diamond rule attempt {resources.attempt}" > {log}.{resources.attempt} 1>&2
        mkdir --parents {params.out_folder} 2>> {log}.{resources.attempt} 1>&2

        # Set the bash variables, based on the snakemake input
        DB_SRC="{input.database}"
        SHM="{params.diamond_shm}"
        NVME="{params.diamond_nvme}"
        DB_SHM="{params.diamond_db_shm}"
        DB_NVME="{params.diamond_db_nvme}"

        # Disable /dev/shm if config says so
        if [ "{params.run_in_shm}" != "True" ]; then
            echo "Config disables /dev/shm use for this rule" 2>> {log}.{resources.attempt} 1>&2
            SHM=""
            DB_SHM=""
        fi

        # Set missing variables to empty sets ""
        : "${{DB_SRC:=}}"
        : "${{DB_SHM:=}}"
        : "${{DB_NVME:=}}"
        : "${{SHM:=}}"
        : "${{NVME:=}}"

        set -u

        echo "DB_SRC: $DB_SRC, COPY_DBS: {params.copy_dbs}" 2>> {log}.{resources.attempt} 1>&2

        if [ {params.copy_dbs} = "True" ]; then
        
            DB_SIZE=$(du -sb $DB_SRC | cut -f1)
            SHM_AVAIL=$(timeout 10s df --output=avail -B1 "$SHM" 2>/dev/null | tail -1 || echo 0)
            NVME_AVAIL=$(timeout 10s df --output=avail -B1 "$NVME" 2>/dev/null | tail -1 || echo 0)

            echo "DB_SIZE: $DB_SIZE, SHM_AVAIL: $SHM_AVAIL, NVME_AVAIL: $NVME_AVAIL" 2>> {log}.{resources.attempt} 1>&2

            NEED_COPY="true"
            if [ "$DB_SIZE" -lt "$SHM_AVAIL" ]; then
                DB_DST="$DB_SHM"
                echo "Set DB_DST to $DB_DST (SHM)" 2>> {log}.{resources.attempt} 1>&2
            elif [ "$DB_SIZE" -lt "$NVME_AVAIL" ]; then
                DB_DST="$DB_NVME"
                echo "Set DB_DST to $DB_DST (NVME)" 2>> {log}.{resources.attempt} 1>&2
            else
                if [ {resources.attempt} -eq {params.retries} ]; then
                    DB_DST="$DB_SRC"
                    NEED_COPY="false"
                    echo "Not enough space, use DB_SRC" 2>> {log}.{resources.attempt} 1>&2
                else
                    echo "DB too large for SHM/NVME, aborting attempt {resources.attempt}" 2>> {log}.{resources.attempt} 1>&2
                    exit 1
                fi
            fi

            if [ "$NEED_COPY" = "true" ]; then
                mkdir -p "$DB_DST"
                cp "$DB_SRC" "$DB_DST" 2>> {log}.{resources.attempt}
                echo "Database copied to $DB_DST" 2>> {log}.{resources.attempt} 1>&2

                echo "Remove file extension from {params.diamond_path}" 2>> {log}.{resources.attempt} 1>&2
                DB="{params.diamond_path}"
                DB_BASE="${{DB%.dmnd}}"

                DB_LOC="$DB_DST/$DB_BASE"
            else
                DB_LOC="$DB_SRC"
            fi
        else
            echo "Skipping DB copy - using source directly" 2>> {log}.{resources.attempt} 1>&2
            DB_LOC="$DB_SRC"
        fi

        echo "Running Diamond using DB_LOC=$DB_LOC" 2>> {log}.{resources.attempt} 1>&2

        diamond blastp -d "$DB_LOC" -q {input.fa} -o {output} -p {threads} 2>> {log}.{resources.attempt}
  
        if [ "{params.run_in_shm}" = "True" ] && [ "$DB_DST" = "$DB_SHM" ]; then
            rm -rfv "$DB_DST" 2>> {log}.{resources.attempt}
        fi

        mv {log}.{resources.attempt} {log}
        """


rule contig_annotate__diamond__summarise:
    """Run R script to summarise Diamond results"""
    input:
        lambda w: [
            CONTIG_DIAMOND / w.diamond_db / f"{assembly_id}.out"
            for assembly_id, library_id in SAMPLE_LIBRARY
        ]
    output:
        CONTIG_DIAMOND / "{diamond_db}" / "summary_a.tsv",
        CONTIG_DIAMOND / "{diamond_db}" / "summary_b.tsv"
    log:
        CONTIG_DIAMOND / "{diamond_db}" / "contig_annotate__diamond__summarise.log"
    benchmark:
        CONTIG_DIAMOND / "{diamond_db}" / "benchmark_summarise.tsv"
    threads: esc("cpus", "contig_annotate__diamond__summarise")
    resources:
        runtime=esc("runtime", "contig_annotate__diamond__summarise"),
        mem_mb=esc("mem_mb", "contig_annotate__diamond__summarise"),
        cpus_per_task=esc("cpus", "contig_annotate__diamond__summarise"),
        slurm_partition=esc("partition", "contig_annotate__diamond__summarise"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'contig_annotate__diamond__summarise')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("contig_annotate__diamond__summarise"))
    params:
        script=lambda w: config["pipeline_folder"] + "workflow/scripts/downstream_scripts/create_featuretable_diamond_" + w.diamond_db + ".R",
        project_folder=WD,
        database=lambda w: w.diamond_db,
    container:
        docker["r_report"]
    shell:
        """
        R -e "project_folder <- '{params.project_folder}'; result_folder <- 'results/contig_annotate/diamond/{params.database}'; source('{params.script}')" &> {log}
        """

rule contig_annotate__diamond:
    """Run all Diamond steps"""
    input:
        [
            CONTIG_DIAMOND / diamond_db / f"{assembly_id}.out"
            for assembly_id in ASSEMBLIES
            for diamond_db in features["databases"]["diamond_contig_protein"]
        ] 
