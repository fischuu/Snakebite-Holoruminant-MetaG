rule mag_annotate__eggnog:
    """Run eggnog over the dereplicated mags"""
    input:
        contigs=MAG_CATALOGUE,
    output:
        directory(EGGNOG),
    log:
        protected(EGGNOG / "eggnog.log"),
    benchmark:
        EGGNOG / "benchmark.tsv"
    container:
        docker["eggnog"]
    params:
        out_dir=EGGNOG,
        db=features["databases"]["eggnog"],
        prefix="eggnog",
        tmp_dir=lambda wc: f"{config['tmp_storage']}/mag_annotate__eggnog",
        copy_dbs=config["copy_dbs"],
    threads: esc("cpus", "mag_annotate__eggnog")
    resources:
        runtime=esc("runtime", "mag_annotate__eggnog"),
        mem_mb=esc("mem_mb", "mag_annotate__eggnog"),
        cpus_per_task=esc("cpus", "mag_annotate__eggnog"),
        slurm_partition=esc("partition", "mag_annotate__eggnog"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__eggnog')['nvme']}",
        attempt=esc("attempt", "mag_annotate__eggnog"),
    shell:
        """
        exec 2>> {log}
        debug "db={params.db} tmp_dir={params.tmp_dir} out_dir={params.out_dir} threads={threads} contigs={input.contigs}"

        # The database is larger than the local disk of many jobs, so it's only copied if it fits
        data_dir={params.db}
        if [ "{params.copy_dbs}" = "True" ]; then
            mkdir --parents {params.tmp_dir}
            db_size=$(du -sbL {params.db} | cut -f1)
            tmp_avail=$(df --output=avail -B1 {params.tmp_dir} | tail -n 1)
            if [ "$db_size" -lt "$tmp_avail" ]; then
                cp -r {params.db}/* {params.tmp_dir}
                data_dir={params.tmp_dir}
                debug "eggnog db copied to $(du -sh {params.tmp_dir} 2>/dev/null | cut -f1) at {params.tmp_dir}"
            else
                echo "The database doesn't fit into {params.tmp_dir}, so it stays where it is" >&2
            fi
        fi

        emapper.py -m diamond \
                   --data_dir "$data_dir" \
                   --itype metagenome \
                   --genepred prodigal \
                   --dbmem \
                   --no_file_comments \
                   --cpu {threads} \
                   -i {input.contigs} \
                   --output_dir {params.out_dir} \
                   -o {params.prefix}

        rm --recursive --force {params.tmp_dir}
        """
