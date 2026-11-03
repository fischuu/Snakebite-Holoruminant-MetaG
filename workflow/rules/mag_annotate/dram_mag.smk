# For now, I took the GTDBTK annotation out, as we get the taxonomic assignment also from the globlal run

_DRAM_ASSEMBLY = DRAMMAG / "{assembly_id}"
_DRAM_ASSEMBLY_TABLES = _DRAM_ASSEMBLY / "annotate"


rule mag_annotate__dram_mag__annotate:
    """Annotate the binned contigs of one assembly with DRAM"""
    input:
        contigs=MAGSCOT / "{assembly_id}.fa.gz",
        reference_data=features["databases"]["dram"],
    output:
        _DRAM_ASSEMBLY_TABLES / "annotations.tsv",
        _DRAM_ASSEMBLY_TABLES / "trnas.tsv",
        _DRAM_ASSEMBLY_TABLES / "rrnas.tsv",
    log:
        _DRAM_ASSEMBLY / "annotate_{assembly_id}.log",
    benchmark:
        _DRAM_ASSEMBLY / "benchmark_annotate.tsv",
    container:
        docker["dram"]
    params:
        dram_config=config["dram-config"],
        tables=lambda wildcards: DRAMMAG / wildcards.assembly_id / "annotate",
    threads: esc("cpus", "mag_annotate__dram_mag__annotate")
    resources:
        runtime=esc("runtime", "mag_annotate__dram_mag__annotate"),
        mem_mb=esc("mem_mb", "mag_annotate__dram_mag__annotate"),
        cpus_per_task=esc("cpus", "mag_annotate__dram_mag__annotate"),
        slurm_partition=esc("partition", "mag_annotate__dram_mag__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram_mag__annotate')['nvme']}",
        attempt=esc("attempt", "mag_annotate__dram_mag__annotate"),
    retries: len(get_escalation_order("mag_annotate__dram_mag__annotate"))
    shell:
        """
        exec > {log} 2>&1
        rm -rf {params.tables}

        # DRAM spawns tRNAscan-SE internally, which does its own $TMPDIR
        # lookup for scratch files -- on this cluster the inherited value is
        # a SLURM per-job path that only exists on the real host /tmp, not
        # inside the container's bind-mounted one (same root cause as the
        # magscot/parallel and bakta/tRNAscan-SE fixes). Point it at our own
        # guaranteed-to-exist subdirectory instead; without this, DRAM.py
        # annotate crashes on tRNAscan-SE and this rule's own fallback below
        # silently swallows that by touching empty output files, which then
        # only surfaces as a confusing pandas EmptyDataError in distill.
        sys_tmp_dir="/tmp/dram_mag.{wildcards.assembly_id}.$$"
        mkdir -p "$sys_tmp_dir"
        export TMPDIR="$sys_tmp_dir"

        echo "Hostname: $(hostname)"
        echo "Temporary directory: $TMPDIR"
        df -h

        debug "assembly_id={wildcards.assembly_id} dram_config={params.dram_config} reference_data={input.reference_data} threads={threads}"
        DRAM.py annotate -i {input.contigs} -o {params.tables} --threads {threads} \
            --config_loc {params.dram_config}

        # DRAM skips a table when it finds nothing of that kind (e.g. no tRNAs), but the
        # rules after this one read all three.
        for table in annotations.tsv trnas.tsv rrnas.tsv; do
            if [ ! -f "{params.tables}/$table" ]; then
                echo "DRAM wrote no $table: leaving an empty file"
                touch "{params.tables}/$table"
            fi
        done

        rm -rf "$sys_tmp_dir"
        """


rule mag_annotate__fix_dram_mag_annotations_scaffold:
    """Patch up DRAM's annotation table (see fix_annotations.py) before distillation"""
    input:
        _DRAM_ASSEMBLY_TABLES / "annotations.tsv",
    output:
        _DRAM_ASSEMBLY_TABLES / "annotations.fixed.tsv",
    log:
        DRAMMAG / "{assembly_id}_fix_annotation.log",
    container:
        docker["assemble"]
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        exec > {log} 2>&1
        debug "input={input} output={output}"
        python {params.script_folder}/fix_annotations.py {input} {output}
        """


rule mag_annotate__dram_mag__distill:
    """Summarize the annotated contigs of one assembly into DRAM's genome/metabolism reports"""
    input:
        annotations=_DRAM_ASSEMBLY_TABLES / "annotations.fixed.tsv",
        trnas=_DRAM_ASSEMBLY_TABLES / "trnas.tsv",
        rrnas=_DRAM_ASSEMBLY_TABLES / "rrnas.tsv",
        reference_data=features["databases"]["dram"],
    output:
        _DRAM_ASSEMBLY / "genome_stats.tsv",
        _DRAM_ASSEMBLY / "metabolism_summary.xlsx",
        _DRAM_ASSEMBLY / "product.tsv",
    log:
        _DRAM_ASSEMBLY / "distill.log2",
    benchmark:
        _DRAM_ASSEMBLY / "benchmark_distill.tsv",
    container:
        docker["dram"]
    threads: esc("cpus", "mag_annotate__dram_mag__distill")
    resources:
        runtime=esc("runtime", "mag_annotate__dram_mag__distill"),
        mem_mb=esc("mem_mb", "mag_annotate__dram_mag__distill"),
        cpus_per_task=esc("cpus", "mag_annotate__dram_mag__distill"),
        slurm_partition=esc("partition", "mag_annotate__dram_mag__distill"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram_mag__distill')['nvme']}",
        attempt=esc("attempt", "mag_annotate__dram_mag__distill"),
    retries: len(get_escalation_order("mag_annotate__dram_mag__distill"))
    params:
        dram_config=config["dram-config"],
        assembly_folder=lambda wildcards: DRAMMAG / wildcards.assembly_id,
    shell:
        """
        exec > {log} 2>&1
        workdir={params.assembly_folder}/distill_tmp
        debug "assembly_id={wildcards.assembly_id} dram_config={params.dram_config} workdir=$workdir threads={threads}"

        # DRAM wants to create its output folder itself
        rm -rf "$workdir"

        DRAM.py distill -i {input.annotations} -o "$workdir" \
            --trna_path {input.trnas} --rrna_path {input.rrnas} --config_loc {params.dram_config}

        mv "$workdir"/* {params.assembly_folder}/
        rm -rf "$workdir"
        """


rule mag_annotate__dram_mags:
    """Run DRAM over the sample-wise mags"""
    input:
        expand(_DRAM_ASSEMBLY / "genome_stats.tsv", assembly_id=ASSEMBLIES),
