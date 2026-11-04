_DRAM_TABLES = DRAM / "annotate"


rule mag_annotate__dram__annotate:
    """Annotate the dereplicated genome catalogue with DRAM"""
    input:
        catalogue=MAG_CATALOGUE,
        taxonomy=GTDBTK / "gtdbtk.summary.tsv",
        reference_data=features["databases"]["dram"],
    output:
        _DRAM_TABLES / "annotations.tsv",
        _DRAM_TABLES / "trnas.tsv",
        _DRAM_TABLES / "rrnas.tsv",
        _DRAM_TABLES / "genes.faa",
    log:
        DRAM / "annotate.log",
    benchmark:
        DRAM / "benchmark_annotate.tsv",
    container:
        docker["dram"]
    params:
        dram_config=config["dram-config"],
    threads: esc("cpus", "mag_annotate__dram__annotate")
    resources:
        runtime=esc("runtime", "mag_annotate__dram__annotate"),
        mem_mb=esc("mem_mb", "mag_annotate__dram__annotate"),
        cpus_per_task=esc("cpus", "mag_annotate__dram__annotate"),
        slurm_partition=esc("partition", "mag_annotate__dram__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram__annotate')['nvme']}",
        attempt=esc("attempt", "mag_annotate__dram__annotate"),
    shell:
        """
        exec > {log} 2>&1
        debug "dram_config={params.dram_config} reference_data={input.reference_data} threads={threads}"
        rm -rf {_DRAM_TABLES}

        # See mag_annotate__dram_mag__annotate: DRAM spawns tRNAscan-SE
        # internally, which independently reads $TMPDIR for its own scratch
        # files -- point it at a guaranteed-to-exist subdirectory instead of
        # the inherited (container-invisible) SLURM per-job path.
        sys_tmp_dir="/tmp/dram.$$"
        mkdir -p "$sys_tmp_dir"
        export TMPDIR="$sys_tmp_dir"

        echo "host: $(hostname)"
        echo "TMPDIR: $TMPDIR"
        df -h

        DRAM.py annotate -i {input.catalogue} -o {_DRAM_TABLES} --threads {threads} \
            --gtdb_taxonomy {input.taxonomy} --config_loc {params.dram_config}

        # DRAM skips a table when it finds nothing of that kind (e.g. no tRNAs), but the
        # rules after this one read all three.
        for table in annotations.tsv trnas.tsv rrnas.tsv; do
            if [ ! -f "{_DRAM_TABLES}/$table" ]; then
                echo "DRAM wrote no $table: leaving an empty file"
                touch "{_DRAM_TABLES}/$table"
            fi
        done

        rm -rf "$sys_tmp_dir"
        """

rule mag_annotate__fix_dram_annotations_scaffold:
    """Patch up DRAM's annotation table (see fix_annotations.py) before distillation"""
    input:
        _DRAM_TABLES / "annotations.tsv",
    output:
        _DRAM_TABLES / "annotations.fixed.tsv",
    log:
        DRAM / "fix_annotation.log",
    container:
        docker["assemble"]
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        python {params.script_folder}/fix_annotations.py {input} {output} > {log} 2>&1

        # The script call above truncates {log}, so this has to be logged after it.
        debug "input={input} output={output}" 2>> {log}
        """

rule mag_annotate__dram__distill:
    """Summarize the annotated genomes into DRAM's genome/metabolism reports"""
    input:
        annotations=_DRAM_TABLES / "annotations.fixed.tsv",
        trnas=_DRAM_TABLES / "trnas.tsv",
        rrnas=_DRAM_TABLES / "rrnas.tsv",
        reference_data=features["databases"]["dram"],
    output:
        DRAM / "genome_stats.tsv",
        DRAM / "metabolism_summary.xlsx",
        DRAM / "product.html",
        DRAM / "product.tsv",
    log:
        DRAM / "distill.log2",
    benchmark:
        DRAM / "benchmark_distill.tsv",
    container:
        docker["dram"]
    threads: esc("cpus", "mag_annotate__dram__distill")
    resources:
        runtime=esc("runtime", "mag_annotate__dram__distill"),
        mem_mb=esc("mem_mb", "mag_annotate__dram__distill"),
        cpus_per_task=esc("cpus", "mag_annotate__dram__distill"),
        slurm_partition=esc("partition", "mag_annotate__dram__distill"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram__distill')['nvme']}",
        attempt=esc("attempt", "mag_annotate__dram__distill"),
    params:
        dram_config=config["dram-config"],
    shell:
        """
        exec > {log} 2>&1
        workdir={DRAM}/distill_tmp
        debug "dram_config={params.dram_config} workdir=$workdir threads={threads}"

        # DRAM wants to create its output folder itself
        rm -rf "$workdir"

        DRAM.py distill -i {input.annotations} -o "$workdir" \
            --trna_path {input.trnas} --rrna_path {input.rrnas} --config_loc {params.dram_config}

        mv "$workdir"/* {DRAM}/
        rm -rf "$workdir"
        """

rule mag_annotate__dram:
    """Run DRAM annotation and distillation over the dereplicated genome catalogue"""
    input:
        rules.mag_annotate__dram__distill.output,
