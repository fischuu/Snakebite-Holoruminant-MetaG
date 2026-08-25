rule read_annotate__kraken2__assign:
    """Classify every sample against one kraken2 database in a single job

    kraken2 has no way to keep the database resident across multiple
    single-sample invocations, so it's staged once onto fast local storage
    (/dev/shm, falling back to NVMe, falling back to running in place on the
    final retry) and every sample is classified against that one copy.
    NOTE: if the job is killed, a staged copy may be left behind in /dev/shm.
    """
    input:
        forwards=[
            FASTP / f"{sample_id}.{library_id}_1.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
        reverses=[
            FASTP / f"{sample_id}.{library_id}_2.fq.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
        database=lambda w: features["databases"]["kraken2"][w.kraken_db],
    output:
        out_gzs=[
            KRAKEN2 / "{kraken_db}" / f"{sample_id}.{library_id}.out.gz"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
        reports=[
            KRAKEN2 / "{kraken_db}" / f"{sample_id}.{library_id}.report"
            for sample_id, library_id in SAMPLE_LIBRARY
        ],
    log:
        KRAKEN2 / "{kraken_db}.log",
    benchmark:
        KRAKEN2 / "benchmark/{kraken_db}.tsv",
    threads: esc("cpus", "read_annotate__kraken2__assign"),
    resources:
        runtime=esc("runtime", "read_annotate__kraken2__assign"),
        mem_mb=esc("mem_mb", "read_annotate__kraken2__assign"),
        cpus_per_task=esc("cpus", "read_annotate__kraken2__assign"),
        slurm_partition=esc("partition", "read_annotate__kraken2__assign"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'read_annotate__kraken2__assign')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("read_annotate__kraken2__assign")),
    params:
        max_attempt=len(get_escalation_order("read_annotate__kraken2__assign")),
        nvme=esc_val("nvme", "read_annotate__kraken2__assign"),
        in_folder=FASTP,
        out_folder=lambda w: KRAKEN2 / w.kraken_db,
        run_in_shm=config["kraken2_shm"],
        copy_dbs=config["copy_dbs"],
        shm_dir=KRAKEN2SHM,
        nvme_dir=KRAKEN2NVME,
        db_shm=lambda w: os.path.join(KRAKEN2SHM, w.kraken_db),
        db_nvme=lambda w: os.path.join(KRAKEN2NVME, w.kraken_db),
    container:
        docker["preprocess"],
    shell: """
        exec > {log}.{resources.attempt} 2>&1
        set +u
        echo "[attempt {resources.attempt}] starting kraken2 assign for {wildcards.kraken_db}"
        mkdir --parents {params.out_folder}

        db_src="{input.database}"
        shm_dir="{params.shm_dir}"
        nvme_dir="{params.nvme_dir}"
        db_shm="{params.db_shm}"
        db_nvme="{params.db_nvme}"

        if [ "{params.run_in_shm}" != "True" ]; then
            echo "config disables /dev/shm staging for this rule"
            shm_dir=""
            db_shm=""
        fi
        : "${{db_src:=}}" "${{shm_dir:=}}" "${{nvme_dir:=}}" "${{db_shm:=}}" "${{db_nvme:=}}"

        avail_bytes() ( timeout 100s df --output=avail -B1 "$1" 2>/dev/null | tail -1 || echo 0 )

        db_dst="$db_src"
        if [ "{params.copy_dbs}" = "True" ]; then
            db_size=$(du -sb "$db_src" | cut -f1)
            shm_avail=$(avail_bytes "$shm_dir")
            nvme_avail=$(avail_bytes "$nvme_dir")
            echo "db_size=$db_size shm_avail=$shm_avail nvme_avail=$nvme_avail"

            if [ "$db_size" -lt "$shm_avail" ]; then
                db_dst="$db_shm"
            elif [ "$db_size" -lt "$nvme_avail" ]; then
                db_dst="$db_nvme"
            elif [ {resources.attempt} -eq {params.max_attempt} ]; then
                echo "no staging space available; running directly from $db_src on the final attempt"
                db_dst="$db_src"
            else
                echo "database too large for available fast storage; aborting attempt {resources.attempt} to trigger escalation"
                exit 1
            fi

            if [ "$db_dst" != "$db_src" ]; then
                echo "staging database to $db_dst"
                mkdir -p "$db_dst"
                rsync --archive --recursive --times "$db_src"/*.k2d "$db_dst"
            fi
        else
            echo "copy_dbs disabled; using database in place at $db_src"
        fi

        echo "running kraken2 against $db_dst"
        for forward in {input.forwards}; do
            sample_id=$(basename "$forward" _1.fq.gz)
            reverse={params.in_folder}/${{sample_id}}_2.fq.gz
            out_gz={params.out_folder}/${{sample_id}}.out.gz
            report={params.out_folder}/${{sample_id}}.report
            sample_log={params.out_folder}/${{sample_id}}.log

            echo "classifying $sample_id"
            kraken2 \
                --db "$db_dst" \
                --threads {threads} \
                --gzip-compressed \
                --paired \
                --output >(pigz --processes {threads} > "$out_gz") \
                --report "$report" \
                --memory-mapping \
                "$forward" "$reverse" \
            > "$sample_log" 2>&1
        done

        if [ "{params.run_in_shm}" = "True" ] && [ "$db_dst" = "$db_shm" ]; then
            rm --recursive --force --verbose "$db_dst"
        fi

        mv {log}.{resources.attempt} {log}
    """


rule read_annotate__kraken2:
    """Aggregate kraken2 reports for every sample against every configured database"""
    input:
        [
            KRAKEN2 / kraken_db / f"{sample_id}.{library_id}.report"
            for sample_id, library_id in SAMPLE_LIBRARY
            for kraken_db in features["databases"]["kraken2"]
        ],
