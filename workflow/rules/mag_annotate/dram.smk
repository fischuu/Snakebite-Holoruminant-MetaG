rule mag_annotate__dram__annotate:
    """Annotate the dereplicated genome catalogue with DRAM"""
    input:
        dereplicated_genomes=DREP / "dereplicated_genomes.fa.gz",
        gtdbtk_summary=GTDBTK / "gtdbtk.summary.tsv",
        dram_db=features["databases"]["dram"],
    output:
        annotation=DRAM / "annotate" / "annotations.tsv",
        trnas=DRAM / "annotate" / "trnas.tsv",
        rrnas=DRAM / "annotate" / "rrnas.tsv",
        genes=DRAM / "annotate" / "genes.faa",
    log:
        DRAM / "annotate.log",
    benchmark:
        DRAM / "benchmark_annotate.tsv",
    container:
        docker["dram"]
    params:
        config=config["dram-config"],
        min_contig_size=1500,
        out_dir=DRAM,
        tmp_dir=DRAM / "annotate",
        parallel_retries=5,
    threads: esc("cpus", "mag_annotate__dram__annotate")
    resources:
        runtime=esc("runtime", "mag_annotate__dram__annotate"),
        mem_mb=esc("mem_mb", "mag_annotate__dram__annotate"),
        cpus_per_task=esc("cpus", "mag_annotate__dram__annotate"),
        slurm_partition=esc("partition", "mag_annotate__dram__annotate"),
        gres=lambda wc, attempt: f"{get_resources(wc, attempt, 'mag_annotate__dram__annotate')['nvme']}",
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__dram__annotate"))
    shell:
        """
        exec > {log} 2>&1
        rm --recursive --force {params.tmp_dir}

        echo "host: $(hostname)"
        echo "TMPDIR: $TMPDIR"
        df -h

        DRAM.py annotate \
            --config_loc {params.config} \
            --input_fasta {input.dereplicated_genomes} \
            --output_dir {params.tmp_dir} \
            --threads {threads} \
            --gtdb_taxonomy {input.gtdbtk_summary}

        # DRAM can skip producing a table when it finds nothing of that kind
        # (e.g. no tRNAs); downstream rules still expect the file to exist.
        for expected in annotations.tsv trnas.tsv rrnas.tsv; do
            path="{params.tmp_dir}/$expected"
            if [ ! -f "$path" ]; then
                echo "DRAM produced no $expected -- creating an empty placeholder"
                touch "$path"
            fi
        done
        """

rule mag_annotate__fix_dram_annotations_scaffold:
    """Patch up DRAM's annotation table (see fix_annotations.py) before distillation"""
    input:
        DRAM / "annotate" / "annotations.tsv",
    output:
        DRAM / "annotate" / "annotations.fixed.tsv",
    log:
        DRAM / "fix_annotation.log",
    container:
        docker["assemble"]
    params:
        script_folder=SCRIPT_FOLDER,
    shell:
        """
        python {params.script_folder}/fix_annotations.py {input} {output} > {log} 2>&1
        """

rule mag_annotate__dram__distill:
    """Summarize the annotated genomes into DRAM's genome/metabolism reports"""
    input:
        annotations=DRAM / "annotate" / "annotations.fixed.tsv",
        trnas=DRAM / "annotate" / "trnas.tsv",
        rrnas=DRAM / "annotate" / "rrnas.tsv",
        dram_db=features["databases"]["dram"],
    output:
        genome=DRAM / "genome_stats.tsv",
        metabolism=DRAM / "metabolism_summary.xlsx",
        product_html=DRAM / "product.html",
        product_tsv=DRAM / "product.tsv",
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
        attempt=get_attempt,
    retries: len(get_escalation_order("mag_annotate__dram__distill"))
    params:
        config=config["dram-config"],
        outdir_tmp=DRAM / "distill_tmp",
        outdir=DRAM,
    shell:
        """
        exec > {log} 2>&1
        # DRAM insists on creating this directory itself, but Snakemake has
        # already created the parent tree ahead of time -- clear it first.
        rm --recursive --force {params.outdir_tmp}

        DRAM.py distill \
            --config_loc {params.config} \
            --input_file {input.annotations} \
            --rrna_path {input.rrnas} \
            --trna_path {input.trnas} \
            --output_dir {params.outdir_tmp}

        mv {params.outdir_tmp}/* {params.outdir}/
        rm --recursive --force {params.outdir_tmp}
        """

rule mag_annotate__dram:
    """Run DRAM annotation and distillation over the dereplicated genome catalogue"""
    input:
        rules.mag_annotate__dram__distill.output,
